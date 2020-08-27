;; Running queries in R via warbler/bigrquery

(defvar bigquery/param-line-regexp "^--|"
  "Pattern for a parameter line comment.")

(defun bigquery/get-next-header-params ()
  "Read parameters from the header comments in the buffer."
  (interactive)
  (when (search-forward-regexp bigquery/param-line-regexp nil t)
      (let ((start (point)))
	(end-of-line)
	(let* ((end (point))
	       (param-string (buffer-substring-no-properties start end)))
	  (string-trim param-string)))))


(defun bigquery/parse-param-line-string (param-line)
  "Parse a parameter line into a list of strings."
  (mapcar 'string-trim (split-string param-line ":")))


(defun bigquery/parse-params (&optional params)
  "Parse all the parameters lines after point."
  (let ((next-param-line (bigquery/get-next-header-params)))
    (if next-param-line
	(let* ((parsed-params
		(bigquery/parse-param-line-string next-param-line))
	       (param (car parsed-params))
	       (val (cadr parsed-params))
	       (updated-params (cons `(,param . ,val) params)))
	  (bigquery/parse-params updated-params))
      params)))


(defun bigquery/parse-header-params ()
  "Parse all parameter lines in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (bigquery/parse-params)))
  

(defun bigquery/params-to-R-list (params)
  "Put parsed parameters into the string repr of an R list."
  (let ((args nil))
    (dolist (p params)
      (when (not (string= (car p) "bq-project"))
	(setq args (cons (format "\"%s\" = \"%s\"" (car p) (cdr p)) args))))
  (format "list(%s)" (string-join args ", "))))


(defun bigquery/create-R-query-funcall (query)
  "Create a string for the R expression to run a QUERY.
Parses the parameter lines in the current buffer and includes them
as the `params` argument to `warbler::bq_run_query`. If there is a 
`bq-project` parameter line, that is passed to the `project` 
argument."
  (let* ((params (bigquery/parse-header-params))
	 (project (alist-get "bq-project" params nil nil 'string=)))
    (format ".bq_result <- warbler::bq_run_query(\"%s\", params = %s%s)"
	    query 
	    (bigquery/params-to-R-list params)
	    (if project (format ", project = \"%s\"" project) ""))))


(defun bigquery/run-query-in-R ()
  "Run the active region or the entire buffer as a query in an R process."
  (interactive)
  (let* ((qry
	 (if (region-active-p)
	     (buffer-substring (region-beginning) (region-end))
	   (buffer-string)))
	 (r-call (bigquery/create-R-query-funcall qry))
	 (ess-proc (ess-get-process (ess-request-a-process nil))))
    (ess-send-string ess-proc r-call t)
    (ess-send-string ess-proc ".bq_result" t)))
 
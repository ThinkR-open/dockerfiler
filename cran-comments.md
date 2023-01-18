## R CMD check results

0 errors | 0 warnings | 0 note

* This is a new release after CRAN's feedback

> Packages which use Internet resources should fail gracefully with an informative message
> if the resource is not available or has changed (and not give a check warning nor error).

What has been done: wrapped the download.file() in get_batch_sysreq in try({}) and added an
informative message.
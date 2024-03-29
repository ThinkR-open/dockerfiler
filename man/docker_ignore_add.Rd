% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dockerignore.R
\name{docker_ignore_add}
\alias{docker_ignore_add}
\title{Create a dockerignore file}
\usage{
docker_ignore_add(path)
}
\arguments{
\item{path}{Where to write the file}
}
\value{
The path to the \code{.dockerignore} file, invisibly.
}
\description{
Create a dockerignore file
}
\examples{
\dontrun{
  docker_ignore_add()
}
}

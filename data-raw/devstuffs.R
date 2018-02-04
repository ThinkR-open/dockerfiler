library(devtools)
library(usethis)
library(desc)

# Remove default DESC
unlink("DESCRIPTION")
# Create and clean desc
my_desc <- description$new("!new")

# Set your package name
my_desc$set("Package", "dockerfiler")

#Set your name
my_desc$set("Authors@R", "person('Colin', 'Fay', email = 'contact@colinfay.me', role = c('cre', 'aut'))")

# Remove some author fields
my_desc$del("Maintainer")

# Set the version
my_desc$set_version("0.0.0.9000")

# The title of your package
my_desc$set(Title = "Easy Dockerfile Creation from R")
# The description of your package
my_desc$set(Description = "Create a Dockerfile straight from your R session.")

# The urls
my_desc$set("URL", "https://github.com/ColinFay/dockerfiler")
my_desc$set("BugReports", "https://github.com/ColinFay/dockerfiler/issues")
# Save everyting
my_desc$write(file = "DESCRIPTION")

# If you want to use the MIT licence, code of conduct, and lifecycle badge
use_mit_license(name = "Colin FAY")
use_code_of_conduct()
use_lifecycle_badge("Experimental")
use_news_md()
use_readme_rmd()

# Get the dependencies
use_package("attempt")
use_package("glue")
use_package("R6")

# Clean your description
use_tidy_description()

#' Compact Sysreqs
#'
#' @param pkg_installs pkg_sysreqs as vector, `pak::pkg_system_requirements` output
#' @param update_cmd command used to update packages, "apt-get update -y" by default
#' @param install_cmd command used to install packages, "apt-get install -y" by default
#' @param clean_cmd command used to clean package folder, "rm -rf /var/lib/apt/lists/*" by default
#'
#' @return vector of compacted command to run to install sysreqs
#' @export
#'
#' @examples
#' pkg_installs <- list("apt-get install -y htop", "apt-get install -y top")
#' compact_sysreqs(pkg_installs)

compact_sysreqs <- function(pkg_installs,
                            update_cmd = "apt-get update -y",
                            install_cmd = "apt-get install -y",
                            clean_cmd ="rm -rf /var/lib/apt/lists/*"){

  # on va extraire tout ce qui commence par pkg_installs
  pkg_ <-  pkg_installs[lapply(pkg_installs,length)!=0]
  apt <-  grepl(pattern = paste0("^",install_cmd),x = pkg_)

  with_apt <- pkg_[apt]
  without_apt <- pkg_[!apt]
  # we choose to not compact unusals sysreqs
  without_apt_out <- unlist(without_apt)

  unlist(without_apt)
  without_apt_out[1] <- paste(update_cmd,     "&&", without_apt_out[1] )
  without_apt_out[length(without_apt_out)] <- paste( without_apt_out[length(without_apt_out)],"&&",clean_cmd)


  paste(
    update_cmd,
    "&&",
    install_cmd,
    without_apt,
    "&&",
    clean_cmd
  )



  compact <- paste(
    unique(unlist(strsplit(gsub(
      with_apt,
      pattern = install_cmd,
      replacement = ""
    ),split = " "))),
    collapse = " "
  )
  if (compact != "") {
    apt_out <- paste(
      update_cmd,
      "&&",
      install_cmd,
      compact,
      "&&",
      clean_cmd
    )
  }else { apt_out <-NULL}

 out<- unlist(c(apt_out,without_apt_out))




  out
}

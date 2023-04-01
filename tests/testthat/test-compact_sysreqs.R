test_that("compact_sysreqs works", {
  pkg_installs <-
    list("apt-get install -y htop", "apt-get install -y top")
  expect_equal(
    compact_sysreqs(pkg_installs),
    "apt-get update -y && apt-get install -y  htop top && rm -rf /var/lib/apt/lists/*"
  )
})
test_that("empty compact_sysreqs works", {
  pkg_installs <-
    list("")
  expect_equal(
    compact_sysreqs(pkg_installs),
    NULL
  )

  pkg_installs <-
NULL
  expect_equal(
    compact_sysreqs(pkg_installs),
    NULL
  )




})

test_that("compact_sysreqs works with chromote", {
  pkg_installs  <- list(character(0), character(0), character(0), character(0),
                        character(0), "apt-get install -y make", character(0), c("[ $(which google-chrome) ] || apt-get install -y gnupg curl",
                                                                                 "[ $(which google-chrome) ] || curl -fsSL -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
                                                                                 "[ $(which google-chrome) ] || DEBIAN_FRONTEND='noninteractive' apt-get install -y /tmp/google-chrome.deb",
                                                                                 "apt-get install -y make libssl-dev libcurl4-openssl-dev"
                        ), character(0), character(0), character(0), character(0),
                        character(0), "apt-get install -y libcurl4-openssl-dev libssl-dev",
                        character(0), character(0), character(0), character(0), "apt-get install -y make",
                        character(0), "apt-get install -y make zlib1g-dev", character(0),
                        character(0), "apt-get install -y make zlib1g-dev", character(0),
                        character(0), character(0), character(0), character(0), character(0),
                        character(0), character(0), character(0), character(0), character(0),
                        "apt-get install -y git", character(0), character(0), "apt-get install -y make",
                        "apt-get install -y make zlib1g-dev", character(0), "apt-get install -y make libssl-dev",
                        character(0), character(0), character(0))



  expect_equal(
    compact_sysreqs(pkg_installs),
    c("apt-get update -y && apt-get install -y  make libcurl4-openssl-dev libssl-dev zlib1g-dev git && rm -rf /var/lib/apt/lists/*",
      "apt-get update -y && [ $(which google-chrome) ] || apt-get install -y gnupg curl",
      "[ $(which google-chrome) ] || curl -fsSL -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
      "[ $(which google-chrome) ] || DEBIAN_FRONTEND='noninteractive' apt-get install -y /tmp/google-chrome.deb",
      "apt-get install -y make libssl-dev libcurl4-openssl-dev && rm -rf /var/lib/apt/lists/*"
    )
  )
})

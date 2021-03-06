# Copyright 2014 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

testthat::context("Unit tests for impact_misc.R")

# Authors: kbrodersen@google.com (Kay Brodersen)
#          gallusser@google.com (Fabian Gallusser)

CreateDummySeries <- function() {
  # Creates a dummy series for testing: 3 years of data, single variable.
  #
  # Returns:
  #   a zoo object with a single series

  set.seed(42)
  dates <- seq.Date(as.Date("2011-01-01"), as.Date("2013-12-31"), by = 1)
  data <- zoo(rnorm(length(dates), dates))
  data[10] <- 5
  data[20] <- -5
  return(data)
}

test_that("repmat", {
  repmat <- CausalImpact:::repmat

  # Test empty input
  expect_error(repmat())

  # Test various standard cases
  expect_error(repmat(data.frame(x = c(1, 2, 3)), 1, 1))
  expect_error(repmat(1, c(1, 2), 1))
  expect_error(repmat(1, 1, c(1, 2)))
  expect_equal(repmat(1, 1, 1), as.matrix(1))
  expect_equal(repmat(1, 2, 1), rbind(1, 1))
  expect_equal(repmat(1, 1, 2), t(c(1, 1)))
  expect_equal(repmat(c(1, 2), 2, 1), rbind(c(1, 2), c(1, 2)))
  expect_equal(repmat("a", 1, 2), as.matrix(t(c("a", "a"))))
  expect_equal(repmat(NA, 1, 2), as.matrix(t(c(NA, NA))))

  # Test documentation example
  expect_equal(repmat(c(10, 20), 1, 2), as.matrix(t(c(10, 20, 10, 20))))
})

test_that("IsWholeNumber", {
  is.wholenumber <- CausalImpact:::is.wholenumber

  # Test empty input
  expect_error(is.wholenumber())

  # Test various standard cases
  expect_error(is.wholenumber("a"))
  expect_equal(is.wholenumber(c(-1, 0, 1, 2, -1.1, 0.1, 1.1)),
              c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(is.wholenumber(NA), NA)

  # Test documentation example
  expect_equal(is.wholenumber(c(1, 1.0, 1.2)), c(TRUE, TRUE, FALSE))
})

test_that("cumsum.na.rm", {
  cumsum.na.rm <- CausalImpact:::cumsum.na.rm

  # Test empty input
  expect_error(is.wholenumber())

  # Test healthy input
  expect_equal(cumsum.na.rm(c(1, NA, 2)), c(1, NA, 3))
  expect_equal(cumsum.na.rm(c(NA, 1, 2)), c(NA, 1, 3))
  expect_equal(cumsum.na.rm(c(1, 2, NA)), c(1, 3, NA))
  expect_equal(cumsum.na.rm(c(1, 2, 3, 4)), cumsum(c(1, 2, 3, 4)))

  # Test degenerate input
  expect_equal(cumsum.na.rm(NULL), NULL)
  expect_equal(cumsum.na.rm(c(NA, NA, NA)), as.numeric(c(NA, NA, NA)))
  expect_equal(cumsum.na.rm(c(NA, NA)), as.numeric(c(NA, NA)))
  expect_equal(cumsum.na.rm(c(0, NA, NA, 0)), c(0, NA, NA, 0))
})

test_that("assert", {
  assert <- CausalImpact:::assert

  expect_error(assert(), NA)
  expect_error(assert(TRUE), NA)
  expect_error(assert(TRUE, "foo"), NA)
  expect_error(assert(3 < 5), NA)
  expect_error(assert(FALSE))
  expect_error(assert(FALSE, "foo"), "foo")
  expect_error(assert(3 > 5), "")
  expect_error(assert(3 > 5, "3 is not greater than 5"), "greater")
})

test_that("ParseArguments", {
  ParseArguments <- CausalImpact:::ParseArguments

  # Test missing input
  expect_error(ParseArguments())

  # Test healthy input
  args <- list(a = 10)
  defaults <- list(a = 1, b = 2)
  result <- ParseArguments(args, defaults)
  expect_equal(result, list(a = 10, b = 2))

  # Test NULL <args>
  result <- ParseArguments(NULL, list(a = 1, b = 2))
  expect_equal(result, list(a = 1, b = 2))

  # Test <args> where an individual field is NULL
  result <- ParseArguments(list(a = NULL), list(a = 1, b = 2))
  expect_equal(result, list(a = 1, b = 2))

  # Test bad input: NULL <defaults>
  expect_error(ParseArguments(NULL, NULL))

  # Test <allow.extra.args>
  result <- ParseArguments(list(c = 1), list(a = 1), allow.extra.args = TRUE)
  expect_equal(result, list(c = 1, a = 1))
  expect_error(ParseArguments(list(c = 1), list(a = 1),
                                allow.extra.args = FALSE))
})

test_that("Standardize", {
  Standardize <- CausalImpact:::Standardize

  # Test missing input
  expect_error(Standardize())

  # Test the basics
  data <- c(-1, 0.1, 1, 2, NA, 3)
  result <- Standardize(data)
  expect_true(is.list(result))
  expect_equal(names(result), c("y", "UnStandardize"))
  expect_equal(result$UnStandardize(result$y), data)

  # Test the maths
  expect_equal(Standardize(c(1, 2, 3))$y, c(-1, 0, 1))

  # Test that inputs are correctly recovered (including zoo input)
  test.data <- list(c(1), c(1, 1, 1), as.numeric(NA), c(1, NA, 3),
                    zoo(c(10, 20, 30), c(1, 2, 3)))
  lapply(test.data, function(data) {
    result <- Standardize(data)
    expect_equal(result$UnStandardize(result$y), data)
  })

  # Test bad input: matrix
  expect_error(Standardize(matrix(rnorm(10), ncol = 2)))
})

test_that("StandardizeAllVariables", {
  StandardizeAllVariables <- CausalImpact:::StandardizeAllVariables
  Standardize <- CausalImpact:::Standardize

  # Test empty input
  expect_error(StandardizeAllVariables())

  # Test healthy input: several columns
  set.seed(1)
  data <- zoo(cbind(rnorm(100) * 100 + 1000,
                    rnorm(100) * 200 + 2000,
                    rnorm(100) * 300 + 3000))
  result <- StandardizeAllVariables(data)
  expect_equal(length(result), 2)
  expect_equal(names(result), c("data", "UnStandardize"))
  sapply(1 : ncol(result$data), function(c) {
    expect_equal(mean(result$data[, c]), 0, tolerance = 0.0001);
    expect_equal(sd(result$data[, c]), 1, tolerance = 0.0001)
  })
  expect_equal(result$UnStandardize, Standardize(data[, 1])$UnStandardize)

  # Test healthy input: single series only
  set.seed(1)
  data <- zoo(rnorm(100) * 100 + 1000)
  result <- StandardizeAllVariables(data)
  expect_equal(length(result), 2)
  expect_equal(names(result), c("data", "UnStandardize"))
  expect_equal(mean(result$data), 0, tolerance = 0.0001)
  expect_equal(sd(result$data), 1, tolerance = 0.0001)
  expect_equal(result$UnStandardize, Standardize(data)$UnStandardize)
})

test_that("InferPeriodIndicesFromData", {
  InferPeriodIndicesFromData <- CausalImpact:::InferPeriodIndicesFromData

  # Test missing input
  expect_error(InferPeriodIndicesFromData())

  # Test healthy input
  expect_equal(InferPeriodIndicesFromData(c(10, 20, 30, NA, NA, NA)),
              list(pre.period = c(1, 3), post.period = c(4, 6)))
  expect_equal(InferPeriodIndicesFromData(c(10, NA)),
              list(pre.period = c(1, 1), post.period = c(2, 2)))
  expect_equal(InferPeriodIndicesFromData(c(NA, NA, 10, 20, NA, NA)),
              list(pre.period = c(3, 4), post.period = c(5, 6)))

  # Test bad input
  expect_error(InferPeriodIndicesFromData(1))
  expect_error(InferPeriodIndicesFromData(NA))
  expect_error(InferPeriodIndicesFromData(c(1, 2, 3)))
  expect_error(InferPeriodIndicesFromData(c(NA, NA, NA)))
  expect_error(InferPeriodIndicesFromData(c(NA, NA, 1, 2, 3)))
})

test_that("PrettifyPercentage", {
  PrettifyPercentage <- CausalImpact:::PrettifyPercentage

  expect_equal(PrettifyPercentage(0.05), "+5%")
  expect_equal(PrettifyPercentage(-0.053), "-5%")
  expect_equal(PrettifyPercentage(c(0.05, 0.01)), c("+5%", "+1%"))
  expect_equal(PrettifyPercentage(0.05, 1), "+5.0%")
  expect_equal(PrettifyPercentage(0.1234, 1), "+12.3%")

  # Test documentation example
  expect_equal(PrettifyPercentage(c(-0.125, 0.2), 2), c("-12.50%", "+20.00%"))
})

test_that("PrettifyNumber", {
  PrettifyNumber <- CausalImpact:::PrettifyNumber

  # Test invalid input
  expect_error(PrettifyNumber("3.141"), "numeric")
  expect_error(PrettifyNumber(3.141, 2), "character")
  expect_error(PrettifyNumber(3.141, round.digits = -2), "round.digits",
               fixed = TRUE)
  expect_error(PrettifyNumber(123.456, letter = "foo"), "letter")

  # Test standard precision
  expect_equal(PrettifyNumber(123.456), "123.5")
  expect_equal(PrettifyNumber(123.456, letter = "K"), "0.1K")
  input <- c(0.01, 0.0123, 1, -123, 12345, -1234567, 1982345670)
  output <- c("0.01", "0.01", "1.0", "-123.0", "12.3K", "-1.2M", "2.0B")
  expect_equal(PrettifyNumber(input), output)

  # Test documentation examples
  expect_equal(PrettifyNumber(c(0.123, 123, 123456)),
               c("0.1", "123.0", "123.5K"))
  expect_equal(PrettifyNumber(3995, letter = "K", round.digits = 2), "4.00K")
  expect_equal(PrettifyNumber(1.234e-3, round.digits = 2), "0.0012")

  # Test manually specified precision
  expect_equal(PrettifyNumber(0.01, round.digits = 1), "0.01")
  expect_equal(PrettifyNumber(-0.0123, round.digits = 2), "-0.012")
  expect_equal(PrettifyNumber(123456, round.digits = 2), "123.46K")

  # Test numbers with trailing zeros
  expect_equal(PrettifyNumber(0.2, round.digits = 2), "0.20")
  expect_equal(PrettifyNumber(-0.2, round.digits = 4), "-0.2000")
  expect_equal(PrettifyNumber(2, round.digits = 2), "2.00")
  expect_equal(PrettifyNumber(-2000, round.digits = 3), "-2.000K")

  # Test non-finite input
  input <- c(NA, NaN, Inf, -Inf)
  expect_equal(PrettifyNumber(input), c("NA", "NaN", "Inf", "-Inf"))
})

test_that("IdentifyNumberAbbreviation", {
  IdentifyNumberAbbreviation <- CausalImpact:::IdentifyNumberAbbreviation

  expect_equal(IdentifyNumberAbbreviation("0.1"), "none")
  expect_equal(IdentifyNumberAbbreviation("0.1K"), "K")
  output <- c("0", "1", "123", "12.3K", "1.2M", "2B")
  letter <- c("none", "none", "none", "K", "M", "B")
  expect_equal(IdentifyNumberAbbreviation(output), letter)

  # Test documentation example
  expect_equal(IdentifyNumberAbbreviation("123.5K"), "K")
})

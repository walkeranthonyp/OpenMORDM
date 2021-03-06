# Copyright 2014-2015 The Pennsylvania State University
#
# OpenMORDM was developed by Dr. David Hadka with guidance from Dr. Klaus
# Keller and Dr. Patrick Reed.  This work was supported by the National
# Science Foundation through the Network for Sustainable Climate Risk
# Management (SCRiM) under NSF cooperative agreement GEO-1240507.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#' Define a new problem formulation.
#' 
#' Constructs a new problem formulation.  The command can either be an R
#' function or a command line executable.  If using a command line executable,
#' the program must follow the MOEA Framework external problem protocol,
#' typically by using the methods in \code{moeaframework.h}.
#' 
#' If using an R function, the function should return a list containing two
#' vectors.  The first vector stores the objective values and the second stores
#' the constraint values.
#' 
#' @param command the R function or executable representing the problem
#' @param nvars the number of decision variables
#' @param nobjs the number of objectives
#' @param nconstrs the number of constraints
#' @param bounds the lower and upper bounds for each decision variable
#' @param names override the column names
#' @param epsilons the epsilon values if using Borg to optimize the problem
#' @param maximize vector indicating the columns to be maximized
#' @export
define.problem <- function(command, nvars, nobjs, nconstrs=0, bounds=NULL, names=NULL, epsilons=NULL, maximize=NULL) {
	if (is.null(bounds)) {
		bounds <- matrix(rep(range(0, 1), nvars), nrow=2)
	}
	
	if (is.null(names)) {
		names <- mordm.generate.names(nvars, nobjs, nconstrs)
	} else if (length(names) == nobjs+nconstrs) {
		names <- append(mordm.generate.names(nvars, 0, 0), names)
	} else if (length(names) == nobjs) {
		names <- append(mordm.generate.names(nvars, 0, 0), append(names, mordm.generate.names(0, 0, nconstrs)))
	} else if (length(names) == nvars + nobjs) {
		names <- append(names, mordm.generate.names(0, 0, nconstrs))
	} else if (length(names) != nvars + nobjs + nconstrs) {
		warning("Incorrect number of names, using defaults")
		names <- mordm.generate.names(nvars, nobjs, nconstrs)
	}
	
	if (is.null(epsilons)) {
		epsilons = rep(0.01, nobjs)
	}
	
	command <- adjust.command(command)
	
	container <- list(command=command, nvars=nvars, nobjs=nobjs, nconstrs=nconstrs, bounds=bounds, names=names, epsilons=epsilons, maximize=maximize)
	class(container) <- "mop"
	container
}

#' Prepends a ./ to commands on non-Windows systems.
#' 
#' @param command the R function or executable representing the problem
#' @export
adjust.command <- function(command) {
	if (!is.function(command)) {
		split.command <- unlist(strsplit(command, "\\s"))
		 
		if (.Platform$OS.type != "windows" && file.exists(split.command[1]) && dirname(split.command[1]) == "." && substring(split.command[1], 1, 1) != ".") {
			split.command[1] <- paste("./", split.command[1], sep="")
			command <- paste(split.command, sep=" ", collapse=" ")
		}
	}
	
	command
}

#' Optimize the problem using the Borg MOEA.
#' 
#' Optimizes the problem.  By default, this method uses the Borg MOEA, which
#' must first be compiled into an executable or shared library on your system.
#' If the problem references an R function, then you must have available the
#' shared library (borg.dll or libborg.so).  If the problem is an external
#' program, then you must have available the Borg executable (borg.exe).  See
#' \code{\link{borg.optimize.function}} and \code{\link{borg.optimize.external}}
#' for details of each method.
#' 
#' The Borg MOEA is free and open for non-commercial users.  Source code can
#' be obtained from \url{http://borgmoea.org}.
#' 
#' @param problem the problem definition
#' @param NFE the maximum number of function evaluations
#' @param ... optional parameters passed to the underlying methods
#' @export
borg.optimize <- function(problem, NFE, ...) {
	if (is.function(problem$command)) {
		borg.optimize.function(problem, NFE, ...)
	} else {
		borg.optimize.external(problem, NFE, ...)
	}
}

#' Optimize a problem using the Borg shared library (borg.dll or libborg.so).
#' 
#' This method is used to optimize a problem defined by an R function.  This
#' method uses R's foreign function interface (FFI) to pass the R function
#' to the Borg MOEA shared library for optimization.  See the Borg MOEA
#' documentation for instructions on compiling borg.dll or libborg.so.
#' 
#' The function should either return a vector containing the objectives and
#' any constraints (e.g., \code{c(o1, o2, o3, c1, c2)}), or a list containing
#' the objectives and constraints as separate elements
#' (e.g., \code{list(c(o1, o2, o3), c(c1, c2))}).  All objectives are minimized.
#' Any non-zero constraint value is considered a constraint violation.
#' 
#' The Borg MOEA is free and open for non-commercial users.  Source code can
#' be obtained from \url{http://borgmoea.org}.
#' 
#' @param problem the problem definition
#' @param NFE the maximum number of function evaluations
#' @param ... additional arguments for setting algorithm parameters
#' @export
#' @import rdyncall
borg.optimize.function <- function(problem, NFE, ...) {
	output <- borg(problem$nvars, problem$nobjs, problem$nconstrs, problem$command, NFE, problem$epsilons, lowerBounds=problem$bounds[1,], upperBounds=problem$bounds[2,], ...)
	
	if (!is.null(problem$maximize)) {
		colnames(output)=problem$names[1:(problem$nvars + problem$nobjs)]
		output[,problem$maximize] <- -output[,problem$maximize]
	}
	
	mordm.read.matrix(as.matrix(output), problem$nvars, problem$nobjs, bounds=problem$bounds, names=problem$names[1:(problem$nvars + problem$nobjs)], maximize=problem$maximize)
}

#' Optimize the problem using the Borg standalone executable (borg.exe).
#' 
#' This method is used to optimize a problem defined by an external executable.
#' The Borg MOEA communicates with the external executable using the open API
#' standardized by the MOEA Framework (\url{http://moeaframework.org}).  See
#' section 5.2 in the user manual for details of using the API.  Since borg.exe
#' targets POSIX systems, this method is typically not available on Windows
#' unless you are running inside Cygwin.  See the Borg MOEA documentation for
#' instructions on compiling borg.exe.
#' 
#' The Borg MOEA is free and open for non-commercial users.  Source code can
#' be obtained from \url{http://borgmoea.org}.
#' 
#' @param problem the problem definition
#' @param NFE the maximum number of function evaluations
#' @param executable the path the the optimization executable
#' @param output the location where the runtime output is stored
#' @param output.frequency the frequency at which data is output
#' @param return.output if \code{TRUE}, this method loads and returns the
#'        contents of the output file
#' @param verbose displays additional information for debugging
#' @export
borg.optimize.external <- function(problem, NFE, executable="borg.exe", output=tempfile(), output.frequency=100, return.output=TRUE, verbose=TRUE) {
	if (is.function(problem$command)) {
		stop("Problem must be an external executable")
	}
	
	#if (!file.exists(executable)) {
	#	stop(paste("Unable to locate ", executable, sep=""))
	#}
	
	command <- paste(executable,
					 "-n", format(NFE, scientific=FALSE),
					 "-v", format(problem$nvars, scientific=FALSE),
					 "-o", format(problem$nobjs, scientific=FALSE),
					 "-c", format(problem$nconstrs, scientific=FALSE),
					 "-l", paste(problem$bounds[1,], collapse=","),
					 "-u", paste(problem$bounds[2,], collapse=","),
					 "-e", paste(problem$epsilons, collapse=","),
					 "-R", output,
					 "-F", format(output.frequency, scientific=FALSE),
					 problem$command)
	
	if (verbose) {
		cat("Running command: ")
		cat(command)
		cat("\n")
	}
	
	system(command)
	
	if (return.output) {
		mordm.read(output, problem$nvars, problem$nobjs, problem$nconstrs, problem$bounds, problem$names, maximize=problem$maximize)
	} else {
		NULL
	}
}

#' Evaluates the decision variables for a given problem.
#' 
#' Evaluates the problem using the given decision variables, returning an
#' object storing the variables, objectives, and constraints.
#' 
#' @param set the decision variables (inputs) to the problem
#' @param problem the problem definition
#' @export
evaluate <- function(set, problem) {
	check.length(set, problem)
	
	# evaluate the model
	if (is.function(problem$command)) {
		output <- evaluate.function(set, problem)
	} else if (is.character(problem$command)) {
		output <- evaluate.external(set, problem)
	} else {
		stop("Command must be a R function or an system command")
	}
	
	# construct the result object
	if (problem$nconstrs > 0) {
		result <- list(vars=set, objs=output[,1:problem$nobjs,drop=FALSE], constrs=output[,(problem$nobjs+1):(problem$nobjs+problem$nconstrs),drop=FALSE])
	} else {
		result <- list(vars=set, objs=output[,1:problem$nobjs,drop=FALSE])
	}
	
	# assign column names
	colnames(result$vars) <- problem$names[1:problem$nvars]
	colnames(result$objs) <- problem$names[(problem$nvars+1):(problem$nvars+problem$nobjs)]
	
	if (problem$nconstrs > 0) {
		colnames(result$constrs) <- problem$names[(problem$nvars+problem$nobjs+1):(problem$nvars+problem$nobjs+problem$nconstrs)]
	}
	
	if (!is.null(problem$maximize)) {
		result$objs[,problem$maximize] <- -result$objs[,problem$maximize]
	}
	
	# return the results
	class(result) <- "samples"
	result
}

#' Evaluates a problem representing a command line executable.
#' 
#' Called by the \code{evaluate} method when the problem is a command line
#' executable.
#' 
#' @param set the decision variables (inputs) to the problem
#' @param problem the problem definition
#' @keywords internal
evaluate.external <- function(set, problem) {
	input <- apply(set, 1, function(x) paste(x, collapse=" "))
	input <- append(input, "")
	
	output <- system(problem$command, intern=TRUE, input=input)
	
	t(sapply(output, function(line) as.double(unlist(strsplit(line, " ", fixed=TRUE))), USE.NAMES=FALSE))
}

#' Evaluates a problem representing a R function.
#' 
#' Called by the \code{evaluate} method when the problem is a R function.
#' 
#' @param set the decision variables (inputs) to the problem
#' @param problem the problem definition
#' @keywords internal
evaluate.function <- function(set, problem) {
	result <- matrix(0, nrow=nrow(set), ncol=problem$nobjs+problem$nconstrs)
	
	for (i in 1:nrow(set)) {
		result[i,] <- unlist(problem$command(set[i,]))
	}
	
	result
	
	#t(apply(set, 1, function(x) unlist(problem$command(x))))
}

#' Ensures the given set contains the correct number of decision variables.
#' 
#' @param set the decision variables (inputs) to the problem
#' @param problem the problem definition
#' @keywords internal
check.length <- function(set, problem) {
	if (is.matrix(set)) {
		if (ncol(set) != problem$nvars) {
			stop("Number of columns must match number of variables")
		}
	} else {
		if (length(set) != problem$nvars) {
			stop("Length of vector must match number of variables")
		}
	}
}

#' Generate uniformly distributed random inputs.
#' 
#' @param nsamples the number of samples to generate
#' @param problem the problem definition
#' @export
usample <- function(nsamples, problem) {
	points <- rand(nsamples, problem$nvars)
	
	for (i in 1:problem$nvars) {
		points[,i] <- (problem$bounds[2,i]-problem$bounds[1,i])*points[,i] + problem$bounds[1,i]
	}
	
	evaluate(points, problem)
}

#' Generate Latin Hypercube sampled random inputs.
#' 
#' @param nsamples the number of samples to generate
#' @param problem the problem definition
#' @export
lhsample <- function(nsamples, problem) {
	points <- randomLHS(nsamples, problem$nvars)
	
	for (i in 1:problem$nvars) {
		points[,i] <- (problem$bounds[2,i]-problem$bounds[1,i])*points[,i] + problem$bounds[1,i]
	}
	
	evaluate(points, problem)
}

#' Returns \code{TRUE} if the decision variables are within bounds.
#' 
#' Checks the decision variables to ensure they are within the problem's
#' lower and upper bounds.
#' 
#' @param points the decision variables
#' @param problem the problem definition
#' @keywords internal
check.bounds <- function(points, problem) {
	check.length(points, problem)
	
	if (is.matrix(points)) {
		for (i in 1:nrow(points)) {
			if (!check.bounds(points[i,], problem)) {
				return(FALSE)
			}
		}
	} else {
		for (i in 1:problem$nvars) {
			if (points[i] < problem$bounds[1,i] || points[i] > problem$bounds[2,i]) {
				return(FALSE)
			}
		}
	}
	
	return(TRUE)
}

#' Generate normally distributed random inputs.
#' 
#' @param mean scalar or vector specifying the mean value for each decision
#'        variable
#' @param sd scalar or vector specifying the standard deviation for each
#'        decision variable
#' @param nsamples the number of samples to generate
#' @param problem the problem definition
#' @export
nsample <- function(mean, sd, nsamples, problem) {
	check.length(mean, problem)
	points <- zeros(nsamples, problem$nvars)
	count <- 0
	
	for (i in 1:nsamples) {
		for (j in 1:problem$nvars) {
			repeat {
				point <- rnorm(1, mean[mod(j, length(mean)) + 1], sd[mod(j, length(sd)) + 1])
				
				if (point >= problem$bounds[1,j] && point <= problem$bounds[2,j]) {
					break
				}
			}
			
			points[i,j] <- point
		}
	}
	
	evaluate(points, problem)
}

#' Computes the robustness metric.
#' 
#' Robustness is represented as a scalar value, where values nearer to
#' positive infinity are considered more robust.  Due to differences in how
#' each robustness metric computes its value, you should look at relative
#' differences in values rather than absolute differences.
#' 
#' @param output the evaluated points
#' @param problem the problem definition
#' @param method the robustness metric to use (default, variance, constraints,
#'        infogap, or distance)
#' @param verbose display additional information
#' @param ... additional arguments passed to the robustness metric
#' @export
check.robustness <- function(output, problem, method="default", verbose=FALSE, ...) {
	varargs <- list(...)
	varargs$verbose <- verbose
	
	if (is.function(method)) {
		robustness <- do.call(method, c(list(output, problem), varargs))
	} else if (is.character(method)) {
		if (method == "default") {
			robustness <- do.call(robustness.default, c(list(output, problem), varargs))
		} else if (method == "variance") {
			robustness <- do.call(robustness.variance, c(list(output, problem), varargs))
		} else if (method == "constraints") {
			robustness <- do.call(robustness.constraints, c(list(output, problem), varargs))
		} else if (method == "infogap" || method == "gap") {
			robustness <- do.call(robustness.gap, c(list(output, problem), varargs))
		} else if (method == "distance") {
			robustness <- do.call(robustness.distance, c(list(output, problem), varargs))
		} else {
			stop("Unsupported robustness method")
		}
	} else {
		stop("Unsupported robustness method")
	}
	
	if (verbose) {
		cat("    Overall Robustness: ")
		cat(robustness)
		cat("\n\n")
	}
	
	robustness
}

#' Experimental robustness metric based on info gap.
#' 
#' Info gap measures the distance from the original point to the nearest
#' constraint boundary.  This experimental implementation approximates this
#' distance by computing the distance based on the sampled points.
#' 
#' @param output the evaluated points
#' @param problem the problem definition
#' @param weights unused
#' @param verbose unused
#' @param original.point the original point being analyzed
robustness.gap <- function(output, problem, weights=NULL, verbose=FALSE, original.point=NULL) {
	if (problem$nconstrs > 0) {
		if (is.null(original.point)) {
			# estimate the original point since one was not provided
			vars <- apply(output$vars, 2, mean)
		} else {
			vars <- original.point$vars
		}
		
		distances <- apply(output$vars, 1, function(x) dist(rbind(vars, x))[1])
		feasible <- apply(output$constrs, 1, function(x) all(x == 0.0))
		
		if (any(!feasible)) {
			indx <- order(distances)
			last <- min(which(!feasible[indx]))
			distances[last]
		} else {
			max(distances)
		}
	} else {
		# Can't compute stability region if there are no constraints
		1
	}
}

#' Robustness metric based on constraint violations.
#' 
#' Measures the percentage of the sampled points that violate constraints.
#' 
#' @param output the evaluated points
#' @param problem the problem definition
#' @param weights unused
#' @param verbose unused
#' @param original.point unused
robustness.constraints <- function(output, problem, weights=NULL, verbose=FALSE, original.point=NULL) {
	nsamples <- nrow(output$vars)
	robustness <- 1
	
	if (problem$nconstrs > 0) {
		nviolations <- sum(1*apply(output$constrs, 1, function(x) any(x != 0.0)))
		robustness <- robustness-nviolations/nsamples
		
		if (verbose) {
			cat("    Constraint Violations: ")
			cat(sprintf("%0.1f", 100*nviolations/nsamples))
			cat(" %\n")
		}
	}
	
	robustness
}

#' Default robustness metric.
#' 
#' The default robustness metric that combines variances and constraint
#' violations.
#' 
#' @param output the evaluated points
#' @param problem the problem definition
#' @param weights the weights assigned to each objective
#' @param verbose display additional information
#' @param original.point the original point being analyzed
robustness.default <- function(output, problem, weights=NULL, verbose=FALSE, original.point=NULL) {
	robustness <- robustness.variance(output, problem, weights, verbose, original.point)
	robustness * (2-robustness.constraints(output, problem, weights, verbose, original.point))
}

#' Robustness metric based on distance.
#' 
#' Measures the average distance from the original point to the sampled points.
#' This is slightly different from variance in that variance is not effected
#' by translational distance.  I.e., two point clouds have the same variance,
#' but one is offset more.
#' 
#' @param output the evaluated points
#' @param problem the problem definition
#' @param weights unused
#' @param verbose unused
#' @param original.point the original point being analyzed
robustness.distance <- function(output, problem, weights=NULL, verbose=FALSE, original.point=NULL) {
	if (is.null(original.point)) {
		0
	} else {
		distances <- apply(output$objs, 1, function(x) dist(rbind(original.point$objs, x))[1])
		-sqrt(sum(distances^2)/length(distances))
	}
}

#' Robustness metric based on variance.
#' 
#' Measures the variance of the sampled points.
#' 
#' @param output the evaluated points
#' @param problem the problem definition
#' @param weights the weights assigned to each objective
#' @param verbose display additional information
#' @param original.point the original point being analyzed
robustness.variance <- function(output, problem, weights=NULL, verbose=FALSE, original.point=NULL) {
	nsamples <- nrow(output$vars)
	robustness <- 0
	
	if (is.null(weights)) {
		weights <- rep(1, problem$nobjs)
	}
	
	for (i in 1:problem$nobjs) {
		sd.norm <- sd(output$objs[,i])
		robustness <- robustness - weights[i]*sd.norm
		
		if (verbose) {
			cat("    Objective ")
			cat(i)
			cat(" Stdev: ")
			cat(sd.norm)
			cat("\n")
		}
	}
	
	robustness
}

#' Determines number of replicates for sensitivity analysis.
#' 
#' Calculates the number of replicates / levels required by the sensitivity
#' analysis method to produce approximately the given number of samples
#' 
#' @param problem the problem definition
#' @param nsamples the desired number of samples
#' @param method the sensitivity analysis method
sensitivity.levels <- function(problem, nsamples, method) {
	if (method == "fast99") {
		ceiling(nsamples / problem$nvars)
	} else if (method == "sobol") {
		ceiling(nsamples / (problem$nvars+1))
	} else if (method == "sobol2002") {
		ceiling(nsamples / (problem$nvars+2))
	} else if (method == "sobol2007") {
		ceiling(nsamples / (problem$nvars+2))
	} else if (method == "sobolEff") {
		ceiling(nsamples / (problem$nvars+1))
	} else if (method == "soboljansen") {
		ceiling(nsamples / (problem$nvars+2))
	} else if (method == "sobolmara") {
		ceiling(nsamples / 2)
	} else if (method == "sobolroalhs") {
		ceiling(nsamples / 2)
	} else if (method == "morris") {
		ceiling(nsamples / (problem$nvars+1))
	} else if (method == "pcc" || method == "src") {
		nsamples
	} else if (method == "plischke") {
		nsamples
	} else {
		stop("Unsupported method")
	}
}

#' Standardized interface for sensitivity analysis methods.
#' 
#' Attempts to standardize the use of various sensitivity analysis methods.
#' Supports all of the methods provided by the sensitivity library except for
#' those using metamodels.
#' 
#' @details
#' In addition to using the same inputs for each method, the outputs are also
#' standardized.  For methods computing the first-order indices, the output
#' contains the sensitivity indices (\code{Si}) and a ranking (\code{rank}).
#' Methods computing total-order indices, the output contains the total
#' sensitivity indices (\code{Si.total}) and the ranking (\code{rank.total}).
#' Where available, the output may also contain confidence intervals
#' (\code{Ci} and \code{Ci.total}).
#' 
#' @param problem the problem definition
#' @param objective the function, objective index, or objective name whose
#'        sensitivity is being computed
#' @param nsamples the desired number of samples
#' @param method string representation of the sensitivity analysis method
#'        (fast99, sobol, sobol2002, sobol2007, sobolEff, soboljansen,
#'        sobolmara, sobolroalhs, morris, prc, src, or plischke)
#' @param verbose if \code{TRUE}, print additional information
#' @param plot if \code{TRUE}, generate any output plots
#' @param raw if \code{TRUE}, return the raw model output; otherwise return the
#'        standardized output
#' @param collapse if \code{TRUE}, collapses the list representation of the
#'        variables, objectives, and constraints into a matrix representation
#' @param ... additional options passed to the sensitivity analysis method
#' @export
#' @importFrom boot boot
#' @importFrom boot boot.ci
compute.sensitivity <- function(problem, objective, nsamples, method="fast99", verbose=FALSE, plot=FALSE, raw=FALSE, collapse=TRUE, ...) {
	varargs <- list(...)
	
	n <- sensitivity.levels(problem, nsamples, method)
	
	if (method == "fast99") {
		if (is.null(varargs$q)) {
			varargs$q <- "qunif"
		}
		
		if (is.null(varargs$q.arg)) {
			varargs$q.arg <- list(min=0, max=1)
		}
		
		model <- do.call(fast99, c(list(model=NULL, factors=problem$nvars, n=n), varargs))
	} else if (method == "sobol") {
		X1 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		X2 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		model <- do.call(sobol, c(list(model=NULL, X1, X2), varargs))
	} else if (method == "sobol2002") {
		X1 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		X2 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		model <- do.call(sobol2002, c(list(model=NULL, X1, X2), varargs))
	} else if (method == "sobol2007") {
		X1 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		X2 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		model <- do.call(sobol2007, c(list(model=NULL, X1, X2), varargs))
	} else if (method == "sobolEff") {
		X1 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		X2 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		model <- do.call(sobolEff, c(list(model=NULL, X1, X2), varargs))
	} else if (method == "soboljansen") {
		X1 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		X2 <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		model <- do.call(soboljansen, c(list(model=NULL, X1, X2), varargs))
	} else if (method == "sobolmara") {
		X <- data.frame(matrix(runif(problem$nvars*n), nrow=n))
		model <- do.call(sobolmara, c(list(model=NULL, X), varargs))
	} else if (method == "sobolroalhs") {
		if (is.null(varargs$order)) {
			varargs$order <- 1
		}
		
		model <- do.call(sobolroalhs, c(list(model=NULL, factors=problem$nvars, levels=n), varargs))
	} else if (method == "morris") {
		if (is.null(varargs$design)) {
			varargs$design <- list(type="oat", levels=5, grid.jump=3)
		}
		
		model <- do.call(morris, c(list(model=NULL, factors=problem$nvars, r=n), varargs))
	} else if (method == "pcc" || method == "src") {
		model <- list(X=data.frame(matrix(runif(problem$nvars*n), nrow=n)))
	} else if (method == "plischke") {
		model <- list(X=matrix(runif(problem$nvars*n), nrow=n))
	} else {
		stop("Unsupported method")
	}
	
	# ensure the model inputs are valid
	if (any(is.nan(unlist(model$X)))) {
		stop("Invalid sampling method, try a different method or increase the number of samples")
	}
	
	# scale the model inputs
	vars <- t(apply(model$X, 1, function(x) (problem$bounds[2,]-problem$bounds[1,])*x + problem$bounds[1,]))
	
	# evaluate the model
	output <- evaluate(vars, problem)
	
	# calculate the response vector
	if (is.function(objective)) {
		if (collapse) {
			downselect <- function(output, index) {
				if (is.null(output$constrs)) {
					result <- matrix(c(output$vars[index,], output$objs[index,]), nrow=1)
				} else {
					result <- matrix(c(output$vars[index,], output$objs[index,], output$constrs[index,]), nrow=1)
				}
				
				colnames(result) <- problem$names
				result
			}
		} else {
			downselect <- function(output, index) {
				if (is.null(output$constrs)) {
					list(vars=output$vars[index,,drop=FALSE],
						 objs=output$objs[index,,drop=FALSE])
				} else {
					list(vars=output$vars[index,,drop=FALSE],
						 objs=output$objs[index,,drop=FALSE],
						 constrs=output$constrs[index,,drop=FALSE])
				}
			}
		}
		
		y <- sapply(1:nrow(output$vars), function(i) {
			if (verbose) {
				cat("Evaluating sample ")
				cat(i)
				cat("\n")
			}
			
			objective(downselect(output, i))
		})
	} else if (is.character(objective) && length(objective) == 1) {
		if (objective %in% colnames(output$vars)) {
			y <- output$vars[,objective]
		} else if (objective %in% colnames(output$objs)) {
			y <- output$objs[,objective]
		} else if (!is.null(output$constrs) && objective %in% colnames(output$constrs)) {
			y <- output$constrs[,objective]
		} else {
			stop("Unable to find matching column name")
		}
	} else if (is.numeric(objective) && length(objective) == 1) {
		y <- output$objs[,objective]
	} else {
		stop("Invalid objective, must be the objective index, a column name, or a function")
	}
	
	# compute the sensitivity indices
	if (method == "pcc") {
		model <- do.call(pcc, c(list(model$X, y), varargs))
	} else if (method == "src") {
		model <- do.call(src, c(list(model$X, y), varargs))
	} else if (method == "plischke") {
		model <- do.call(deltamim, c(list(model$X, y), varargs))
	} else {
		tell(model, y)
	}
	
	# display or plot the results
	if (verbose) {
		print(model)
	}
	
	if (plot) {
		plot(model)
	}
	
	# convert the results to a standard format
	if (raw) {
		model
	} else {
		if (method == "fast99") {
			Si <- model$D1/model$V
			rank <- rev(order(Si))
			Si.total <- 1 - model$Dt / model$V
			rank.total <- rev(order(Si.total))
			list(Si=Si, rank=rank, Si.total=Si.total, rank.total=rank.total)
		} else if (method == "sobol" || method == "sobolEff" || method == "sobolmara") {
			Si <- model$S[,"original"]
			rank <- rev(order(Si))
			
			if ("min. c.i." %in% names(model$S)) {
				Ci <- model$S[,c("min. c.i.", "max. c.i.")]
				list(Si=Si, rank=rank, Ci=Ci)
			} else {
				list(Si=Si, rank=rank)
			}
		} else if (method == "sobolroalhs") {
			Si <- model$S[1:problem$nvars,"original"]
			rank <- rev(order(Si))
			
			if ("min. c.i." %in% names(model$S)) {
				Ci <- model$S[1:problem$nvars,c("min. c.i.", "max. c.i.")]
				list(Si=Si, rank=rank, Ci=Ci)
			} else {
				list(Si=Si, rank=rank)
			}
		} else if (method == "sobol2002" || method == "sobol2007" || method == "soboljansen") {
			Si <- model$S[,"original"]
			rank <- rev(order(Si))
			Si.total <- model$T[,"original"]
			rank.total <- rev(order(Si.total))
			
			if ("min. c.i." %in% names(model$S)) {
				Ci <- model$S[,c("min. c.i.", "max. c.i.")]
				Ci.total <- model$T[,c("min. c.i.", "max. c.i.")]
				list(Si=Si, rank=rank, Ci=Ci, Si.total=Si.total, rank.total=rank.total, Ci.total=Ci.total)
			} else {
				list(Si=Si, rank=rank, Si.total=Si.total, rank.total=rank.total)
			}
		} else if (method == "morris") {
			Si <- apply(model$ee, 2, mean)
			rank <- rev(order(Si))
			list(Si=Si, rank=rank)
		} else if (method == "pcc") {
			Si <- model$PCC[,"original"]
			rank <- rev(order(Si))
			
			if ("min. c.i." %in% names(model$PCC)) {
				Ci <- model$PCC[,c("min. c.i.", "max. c.i.")]
				list(Si=Si, rank=rank, Ci=Ci)
			} else {
				list(Si=Si, rank=rank)
			}
		} else if (method == "src") {
			Si <- model$SRC[,"original"]
			rank <- rev(order(Si))
			
			if ("min. c.i." %in% names(model$SRC)) {
				Ci <- model$SRC[,c("min. c.i.", "max. c.i.")]
				list(Si=Si, rank=rank, Ci=Ci)
			} else {
				list(Si=Si, rank=rank)
			}
		} else if (method == "plischke") {
			if (!is.null(varargs$nboot)) {
				if (is.null(varargs$conf)) {
					varargs$conf = 0.95
				}
				
				estim.plischke <- function(data, i=1:nrow(data)) {
					d <- as.matrix(data[i, ])
					k <- ncol(d)
					res <- do.call(deltamim, c(list(d[,-k], d[,k]), varargs))
					c(res$Si)
				}
				
				V.boot <- boot(cbind(vars, y), estim.plischke, R = varargs$nboot)
				V <- bootstats(V.boot, varargs$conf, "basic")
				rownames(V) <- paste("X", 1:problem$nvars, sep="")

				list(Si=model$Si, rank=model$rank, Ci=V[,c("min. c.i.", "max. c.i.")])
			} else {
				list(Si=model$Si, rank=model$rank)
			}
		}
	}
}

# This function is not exported from the statistics library, so it is copied
# here.  This is used to compute the bootstrap confidence intervals for the
# Plischke method.
bootstats <- function(b, conf = 0.95, type = "norm") {
	p <- length(b$t0)
	lab <- c("original", "bias", "std. error", "min. c.i.", "max. c.i.")
	out <-  as.data.frame(matrix(nrow = p, ncol = length(lab),
								 dimnames = list(NULL, lab)))
	
	for (i in 1 : p) {
		# original estimation, bias, standard deviation
		out[i, "original"] <- b$t0[i]
		out[i, "bias"] <- mean(b$t[, i]) - b$t0[i]
		out[i, "std. error"] <- sd(b$t[, i])
		
		# confidence interval
		if (type == "norm") {
			ci <- boot.ci(b, index = i, type = "norm", conf = conf)
			if (!is.null(ci)) {
				out[i, "min. c.i."] <- ci$norm[2]
				out[i, "max. c.i."] <- ci$norm[3]
			}
		} else if (type == "basic") {
			ci <- boot.ci(b, index = i, type = "basic", conf = conf)
			if (!is.null(ci)) {
				out[i, "min. c.i."] <- ci$basic[4]
				out[i, "max. c.i."] <- ci$basic[5]
			}
		}
	}
	
	return(out)
}

#' Generates uncertainty samples using Latin hypercube sampling.
#' 
#' Returns a matrix storing uncertainty samples.  The first argument to this
#' function is the desired number of samples.  The remaining named arguments
#' specify the parameter name and its bounds.  For example, the following
#' generates samples for two parameters, a and b:
#'    \code{factors <- sample.lhs(100, a=c(0, 10), b=c(-1, 1))}
#' 
#' @param nsamples the desired number of samples
#' @param ... the named arguments specifying the bounds of each parameter
#' @export
sample.lhs <- function(nsamples, ...) {
	args <- list(...)
	param_names = names(args)
	
	if (is.null(param_names) || "" %in% param_names) {
		error("Either no parameters specified or missing parameter names")
	}
	
	factors <- randomLHS(nsamples, length(args))
	colnames(factors) <- param_names
	
	for (param in param_names) {
		param_max <- max(unlist(args[param]))
		param_min <- min(unlist(args[param]))
		factors[,param] <- factors[,param]*(param_max-param_min) + param_min
	}
	
	return(factors)
}

#' Assigns the parameters for the given function, returning a new function.
#' 
#' Uses the functional package to pre-specify or override the named parameters
#' for a function.
#' 
#' @param fcn the function
#' @param ... the values for the named parameters
#' @export
with.parameters <- function(fcn, ...) {
	require(functional)
	do.call(Curry, unlist(list(fcn, ...)))
}

#' Creates models for each uncertainty parameterization.
#' 
#' Takes the model, which must be defined using an R function, and creates
#' many instances of the model for each uncertainty parameterization.  The
#' names of the uncertainty parameters must match the optional, named
#' arguments to the R function.
#' 
#' @param problem the problem definition from \code{define.problem}
#' @param factors the uncertainty parameterizations from \code{sample.lhs}
#' @export
create.uncertainty.models <- function(problem, factors) {
	if (!is.function(problem$command)) {
		error("create.models only works on problems defined using an R function")
	}
	
	model_calls <- apply(factors, 1, function(x) {
		with.parameters(problem$command, unlist(x))
	})
	
	models <- lapply(model_calls, function(command) {
		define.problem(command,
					   problem$nvars,
					   problem$nobjs,
					   problem$nconstrs,
					   bounds=problem$bounds,
					   names=problem$names,
					   epsilons=problem$epsilons,
					   maximize=problem$maximize)
	})
	
	return(models)
}

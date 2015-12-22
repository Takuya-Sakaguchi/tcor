#' Thresholded distances between columns of a matrix.
#'
#' Unlike the \code{\link{dist}} function which computes
#' distances between matrix _rows_, \code{tdist} computes distances
#' exceeding a threshold between matrix _columns_.
#'
#' Increase p to cut down the total number of candidate pairs evaluated,
#' at the expense of costlier truncated SVDs.
#'
#' This function doesn't work as well generally yet as the \code{\link{tcor}}
#' companion function in this package.
#'
#' @param A an m by n real-valued dense or sparse matrix
#' @param t a threshold distance value
#' @param p projected subspace dimension
#' @param filter "local" filters candidate set sequentially,
#'  "distributed" computes thresholded correlations in a parallel code section which can be
#'  faster but requires that the data matrix is available (see notes).
#' @param method the distance measure to be used, one of
#'          "euclidean", or "manhattan".
#' Any unambiguous substring can be given.
#' @param ... additional arguments passed to \code{\link{irlba}}
#'
#' @return A list with elements:
#' \enumerate{
#'   \item \code{indices} A three-column matrix. The  first two columns contain
#'         indices of vectors meeting the distance threshold \code{t},
#'         the third column contains the corresponding distance value.
#'   \item \code{longest_run} The largest number of successive entries in the
#'     ordered first singular vector within a projected distance defined by the
#'     correlation threshold.
#'   \item \code{n} The total number of _possible_ vectors that meet
#'     the correlation threshold identified by the algorithm.
#'   \item \code{total_time} Total run time.
#' }
#' @importFrom irlba irlba
#' @importFrom stats dist
#' @export
tdist = function(A,
                 t=min(sqrt(apply(A, 2, crossprod))),
                 p=10,
                 filter=c("distributed", "local"),
                 method=c("euclidean", "manhattan"), ...)
{
  filter = match.arg(filter)
  method = match.arg(method)
  if(ncol(A) < p) p = max(1, floor(ncol(A) / 2 - 1))
  t0 = proc.time()
  L  = irlba(A, p, ...)
  t1 = (proc.time() - t0)[[3]]

  normlim = switch(method,
                   euclidean = t ^ 2,
                   maximum = nrow(A) * t ^ 2,  # XXX unlikely to be a good bound XXX
                   manhattan   = t ^ 2)
  full_dist_fun =
    switch(method,
           euclidean = function(idx) vapply(1:nrow(idx), function(k) sqrt(crossprod(A[, idx[k,1]] - A[, idx[k, 2]])), 1),
           manhattan = function(idx) vapply(1:nrow(idx), function(k) sum(abs(A[, idx[k,1]] - A[, idx[k, 2]])), 1),
           maximum = function(idx) vapply(1:nrow(idx), function(k) max(abs(A[, idx[k,1]] - A[, idx[k, 2]])), 1)
  )
  filter_fun =  function(v, t) v <= t

  ans = two_seven(A, L, t, filter, normlim=normlim, full_dist_fun=full_dist_fun, filter_fun=filter_fun)
  return(c(ans, svd_time=t1, total_time=(proc.time() - t0)[[3]]))
}
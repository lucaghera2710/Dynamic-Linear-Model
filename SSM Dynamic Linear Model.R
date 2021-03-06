# Kalman filter, Kalman Smoother and Simulation smoother (Durbin & Koopman 2002)
# for linear State Space Model (univariate and multivariate).

# State space model (Gaussian disturb, see algorithms of Durbin & Koopman "Time Series Analysis by State Space Methods" )

# y_t   = dd + ZZ*a_t  + eps_t     eps_t ~ N(0,H),
# a_t+1 = cc + TT*a_t + RR*eta_t   eta_t ~ N(0,Q),
# a_0 ~ N(a0,P0)


# INPUTS:

# y - data, nobs x T 
# implement a 'mod' (Model structure) function (or list) that returns these outputs:
# dd,ZZ    - measurement equation
# cc,TT,RR - state equation
# a0, P0   - hyperparameters at time 0.
# H, Q     - covariances matrices (measurement and state)

#OUTPUTS:

#output    - 1: mean and variance of filtered latent process and likelihood
#            2: mean and variance of smoothed latent process and likelihood
#            3: simulation smoother and likelihood 

################# ################### ##################

rm (list=ls())

kalmanSSM <- function(y,mod,output){
library(mvtnorm)  
if (NCOL(y)== 1) {
  y <- t(y)
}
  
nobs <- dim(y)[1]
T    <- dim(y)[2]

a0   <- mod$a0
P0   <- mod$P0
cc   <- mod$cc
dd   <- mod$dd
RR   <- mod$RR
TT   <- mod$TT
ZZ   <- mod$ZZ
H    <- mod$H
Q    <- mod$Q
RR   <- mod$RR

m    <- NROW(RR)
r    <- NCOL(RR)

if (output==3) { # simulation smoother
  
               yplus      <-  matrix(NA,nobs,T)
               aplus      <-  matrix(NA,nrow=m,ncol=T+1)
               aplus[,1]  <-  rmvnorm(1,rep(0,m),sigma = P0)
               eps        <-  rmvnorm(T,mean = rep(0,nobs),sigma =as.matrix(H))
               eta        <-  rmvnorm(T,mean = rep(0,m),sigma = as.matrix(Q))
               for(t in 1:T){
                   yplus[,t]   <-    ZZ %*% matrix(aplus[,t]) +   eps[t,]
                   aplus[,t+1]  <-   TT %*% matrix(aplus[,t]) +   RR%*%eta[t,]          
                          }
               
               aplus <-   aplus[,1:T] 
               yy    <-   y - yplus
               }
else {
             yy <- y }
               
yt       <-  matrix(0,nobs,T)
aat      <-  matrix(0,m,T)
PPt      <-  array(NA,dim = c(m,m,T))
vv       <-  matrix(0,nobs,T)
FF       <-  array(NA,dim = c(nobs,nobs,T))
FFinv    <-  array(NA,dim = c(nobs,nobs,T))
KK       <-  array(NA,dim = c(m,nobs,T))

# Likelihood
LogFF = 0
SumSQ = 0
dimNP = 0

at <- matrix(as.vector(a0))
Pt <- P0

for (t in 1:T) {
               
                ypred      <- ZZ %*% at + dd
                vt         <- ifelse(is.na(yy[,t]),matrix(0,nobs,1), yy[,t] - ypred)
                Ft         <- ZZ %*% Pt %*% t(ZZ) + H
                Ftinv      <- solve(Ft)
                Kt         <- TT %*% Pt %*% t(ZZ) %*% Ftinv
                at         <- cc + TT%*%at + Kt%*%vt
                Pt         <- TT %*% Pt %*% t(TT - Kt%*%ZZ) + RR %*% Q %*% t(RR)
              
                vv[,t]     <- vt
                FF[,,t]    <- Ft
                FFinv[,,t] <- Ftinv
                KK[,,t]    <- Kt
                yt[,t]     <- ypred
                aat[,t]    <- at
                PPt[,,t]   <- Pt 
                detFF = det(Ft) 
                LogFF = LogFF + log(detFF)
                SumSQ = SumSQ + t(vt) %*% Ftinv %*% vt
                dimNP = dimNP + nobs
                Sigma = SumSQ / dimNP

                                }

LogL = - 0.5 * (dimNP * log(2 * pi) + LogFF + SumSQ)
Sigma = SumSQ / dimNP

if (output==1) {
  
  return(list(at = aat, Pt = PPt, loglik = LogL, ypred =  yt, Sigma = Sigma))
  
}

rr <- matrix(0,m,T)
alpha_hat <-  matrix(NA,m,T)

# Kalman Smoother
if (output==2) { 
NN <- array(0,dim=c(m,m,T))
alpha_hat[,T] <-  aat[,T]
V_hat         <-  array(0,dim=c(m,m,T))
V_hat[,,T]    <-  PPt[,,T]

for (t in (T-1):1) {
  
  rr[,t]        <-  t(ZZ) %*% FFinv[,,t+1] %*% vv[,t+1] + t(TT-KK[,,t+1] %*% ZZ) %*% rr[,t+1]
  NN[,,t]       <-  t(ZZ) %*% FFinv[,,t+1] %*% ZZ  + (TT-KK[,,t+1] %*% ZZ) %*% NN[,,t+1]
  alpha_hat[,t] <-  aat[,t] + PPt[,,t] %*% rr[,t]
  V_hat[,,t]    <-  PPt[,,t] - PPt[,,t] %*%  NN[,,t] %*% PPt[,,t]
}

return(list(at = alpha_hat, Pt= V_hat, loglik = LogL))

}


if (output==3){

for (t in (T-1):1) {
      rr[,t] <- t(ZZ) %*% FFinv[,,t+1] %*% vv[,t+1] + t(TT-KK[,,t+1] %*% ZZ) %*% rr[,t+1]
                    }

r0  <- t(ZZ) %*% FFinv[,,1] %*% vv[,1] + t(TT-KK[,,1] %*% ZZ) %*% rr[,1]

alpha_hat[,1] <- a0 + as.vector(P0%*%as.matrix(r0))

# Fast Smoother
for(t in 2:T){ 
  
   alpha_hat[,t] <- cc + TT %*% alpha_hat[,t-1]+ (RR %*% Q %*% t(RR)) %*% rr[,t-1]
  
             }

alpha_hat = alpha_hat + aplus

return(list(simstate=alpha_hat))
             
            }

}


# Example: evaluation of loglik with reparametrization for variances params (sigmaeps and sigmaeta).

om <- function(theta) log(theta)

th <- function(omega) exp(omega)

ssm_ml.om <-  function(y,omega,...,optimize=T,output=1){
  
  
  mod <- SSMdynamics(y=y,par = th(omega),...)
  k <- kalmanSSM(y=y,mod = mod,output = output)
  if (optimize==T) {
    
    return(-1*k$loglik)
    
  }
  else return(kf)
  
}

#optim(par  = rep(1,2),fn = ssm_ml.om,y=y, method='L-BFGS-B',control = list(trace=T,maxit=20000)))








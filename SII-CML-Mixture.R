##################################################################
# Longitudinal data analysis by combining multiple likelihood.
##################################################################
rm(list = ls())
require(MASS)
require(ucminf)
require(gee)
require(geepack)
#-----------------------------------------------
# Estimation for Moving Average model.

#Exchangable
exch <- function(para,s) {
  s <- c(s) 
  n <- length(s)
  z <- matrix(para, n,n)
  diag(z) <- 1
  z
}


polys<-function(x,p){
if(length(x)==1)return(x^(0:(p-1)))
else {
y<-matrix(0,length(x),p)
y[,1]<-1
for(i in 1:length(x))
 y[i,-1]<-x[i]^(1:(p-1))
 return(y)
}
}

###############################################
# Data Generation 
###############################################
GenData<-function(rbta,rgma,rlmd,n,ratio)
{
lbta<-length(rbta)
lgma<-length(rgma)
llmd<-length(rlmd)

# conduct the store structure.
Xlist=list()
Ylist=list()
Hlist=list() 
   
m<-rep(0,n) 
ObsTimeMatrix<-matrix(NA,n,maxm.sub)
W<-array(NA,dim=c(n,maxm.sub,maxm.sub-1,lgma))
DataFrame=NULL

n1=n*ratio[1]
n2=n*(ratio[1]+ratio[2])
#-----------------------------------------------
for(i in 1:n1){
   m[i]<-rbinom(1,maxm.sub-1,0.8)+1 
   ti=sort(runif(m[i]))
   ObsTimeMatrix[i,1:m[i]]<-ti
   
   Xlist[[i]]<-cbind(1,mvrnorm(m[i],rep(0,lbta-1),exch(0.5,1:(lbta-1))))
   Hlist[[i]]<-cbind(1,mvrnorm(m[i],rep(0,llmd-1),exch(0.5,1:(llmd-1))))

  Ti<-matrix(0,m[i],m[i])
  for(j in 2:m[i])
    {
     for(k in 2:(j-1))
       {
        W[i,j,k,]<-polys(ti[j]-ti[k],lgma)
        Ti[j,k]=-W[i,j,k,]%*%rgma
       }
    } 
    
  diag(Ti)=rep(1,m[i])
  di<-drop(exp(Hlist[[i]]%*%rlmd))      
  Di<-matrix(0,m[i],m[i]) 
  diag(Di)<-di
  Sigmai<-solve(Ti,tol=1e-300)%*%Di%*%solve(t(Ti),tol=1e-300)
  Ylist[[i]]<-Xlist[[i]]%*%rbta+mvrnorm(1,rep(0,m[i]),Sigma=Sigmai)
  DataFrame=rbind(DataFrame,data.frame(ID=i,Y=Ylist[[i]],X=Xlist[[i]],H=Hlist[[i]],Obstime=na.omit(ObsTimeMatrix[i,])))
}
#-----------------------------------------------
for(i in (n1+1):n2){
   m[i]<-rbinom(1,maxm.sub-1,0.8)+1 
   ti=sort(runif(m[i]))
   ObsTimeMatrix[i,1:m[i]]<-ti
   
   Xlist[[i]]<-cbind(1,mvrnorm(m[i],rep(0,lbta-1),exch(0.5,1:(lbta-1))))
   Hlist[[i]]<-cbind(1,mvrnorm(m[i],rep(0,llmd-1),exch(0.5,1:(llmd-1))))

   Li=matrix(0,m[i],m[i])
   for(j in 2:m[i]){
      for(k in 1:(j-1)){
                       W[i,j,k,]<-polys(ti[j]-ti[k],lgma)
                       Li[j,k]=W[i,j,k,]%*%rgma
                       }
                   }
  diag(Li)=rep(1,m[i])
  di<-drop(exp(Hlist[[i]]%*%rlmd))      
  Di<-matrix(0,m[i],m[i]) 
  diag(Di)<-di
  Sigmai<-Li%*%Di%*%t(Li)
  Ylist[[i]]<-Xlist[[i]]%*%rbta+mvrnorm(1,rep(0,m[i]),Sigma=Sigmai)
  DataFrame=rbind(DataFrame,data.frame(ID=i,Y=Ylist[[i]],X=Xlist[[i]],H=Hlist[[i]],Obstime=na.omit(ObsTimeMatrix[i,])))
}
#-----------------------------------------------
for(i in (n2+1):n){
   m[i]<-rbinom(1,maxm.sub-1,0.8)+1 
   ti=sort(runif(m[i]))
   ObsTimeMatrix[i,1:m[i]]<-ti
   
   Xlist[[i]]<-cbind(1,mvrnorm(m[i],rep(0,lbta-1),exch(0.5,1:(lbta-1))))
   Hlist[[i]]<-cbind(1,mvrnorm(m[i],rep(0,llmd-1),exch(0.5,1:(llmd-1))))

      Ti<-phi<-matrix(0,m[i],m[i])
      ti<-ObsTimeMatrix[i,1:m[i]]

      Ti[1,1]<-1
      for(j in 2:m[i])
         {
          for(k in 1:(j-1))
             {
              W[i,j,k,]<-polys(ti[j]-ti[k],lgma)  
              phi[j,k]<-W[i,j,k,]%*%rgma  
             }
         Ti[j,j]<-prod(sin(phi[j,1:(j-1)]))
         Ti[j,1]<-cos(phi[j,1])
         if(j>2)
           {
           for(l in 2:(j-1)) 
             Ti[j,l]<-cos(phi[j,l])*prod(sin(phi[j,1:(l-1)]))   
           }
        }
         di<-exp(drop(Hlist[[i]]%*%rlmd)/2)
         Di<-diag(di,m[i],m[i])
         Ylist[[i]]<-Xlist[[i]]%*%rbta+Di%*%Ti%*%mvrnorm(1,rep(0,m[i]),Sigma=diag(1,m[i],m[i]))    
         DataFrame=rbind(DataFrame,data.frame(ID=i,Y=Ylist[[i]],X=Xlist[[i]],H=Hlist[[i]],Obstime=na.omit(ObsTimeMatrix[i,])))
}
#-----------------------------------------------
output  <- list(m,W,Xlist,Ylist,Hlist,ObsTimeMatrix,DataFrame)
names(output) <- list("m","W","Xlist","Ylist","Hlist","ObsTimeMatrix","DataFrame")
return(output)
}





######################################################
# MCDF Regression 
######################################################
Reg.MCDF<-function(DATA,theta0)
{
Xlist=DATA$Xlist
Ylist=DATA$Ylist
Hlist=DATA$Hlist

Time.matrix=DATA$ObsTimeMatrix
M=DATA$m

n=length(M)

lbta<-ncol(Xlist[[1]])
llmd<-ncol(Hlist[[1]])
lgma<-3
#-----------------------------------------------
W<-array(NA,dim=c(n,maxm.sub,maxm.sub-1,lgma))

for(i in 1:n)
{  
  for(j in 2:M[i])
     {
     for(k in 1:(j-1))
        {
        W[i,j,k,]<-polys(Time.matrix[i,j]-Time.matrix[i,k],lgma)  
        }
     }
}
#-----------------------------------------------OK
# Setup initial values
X=NULL;
Y=NULL;
H=NULL;
for(i in 1:n)
   {  
   X=rbind(X,Xlist[[i]]);
   H=rbind(H,Hlist[[i]]);
   Y=c(Y, Ylist[[i]]);
   }

#setup the initial parameters     
bta0=theta0[1:lbta]
gma0=theta0[(lbta+1):(lbta+lgma)]
lmd0=theta0[(lbta+lgma+1):(lbta+lgma+llmd)]
#-----------------------------------------------OK
betahatold=bta0+0.1
betahatnew=bta0
Lamhatold=lmd0+0.1
Lamhatnew=lmd0
Gamhatold<-gma0-0.1
Gamhatnew<-gma0

Kbeta=0
while(sum((betahatnew-betahatold)^2)>1e-4)
{
betahatold=betahatnew
Lamhatold=Lamhatnew

# Setup the calculation structure.
Mulist=list()
Rlist=list()

for(i in 1: n)
{
Mulist[[i]]=Xlist[[i]]%*%betahatold
Rlist[[i]]=Ylist[[i]]-Mulist[[i]]
}
#-----------------------------------------------OK
# Calculation for Gamma 

# This part is used to calculate the function G_i(Gam)
Dgi.inv.list=list()
ZtoltaLlastlist=list()
GGam=matrix(0,lgma,lgma)

for(i in 1:n)
{
dgi=exp(Hlist[[i]]%*%Lamhatold)
Dgi.inv=diag(as.vector(1/dgi))
Dgi.inv.list[[i]]=Dgi.inv

# ZiMatrix is to dipict Z(i) in Pourahmadi, 2000.
ZiMatrix=matrix(0,M[i],lgma)

for(j in 2:M[i])
{
Zij=rep(0,lgma)
for(k in 1:(j-1))
{
Zij=Zij+Rlist[[i]][k]* W[i,j,k,]
} 
ZiMatrix[j,]=Zij
} 

ZtoltaLlastlist[[i]]=ZiMatrix
GGam=GGam-t(ZiMatrix)%*%Dgi.inv%*%ZiMatrix
} # end of loop i.

KGam=0
repeat{
Gamhatold=Gamhatnew
U2=rep(0,lgma)
for(i in 1:n)
{U2=U2+t(ZtoltaLlastlist[[i]])%*%Dgi.inv.list[[i]]%*%(Rlist[[i]]-ZtoltaLlastlist[[i]]%*%Gamhatold)}
Gamhatnew=Gamhatold-solve(GGam)%*%U2

KGam=KGam+1
if(sum((Gamhatnew-Gamhatold)^2)<=1e-4|KGam>50){break}
}
Gammahat=Gamhatnew
#-----------------------------------------------
# Calculation for Lambda 
EpsilonLamlist=list()
Tlist=list()
fvectoRlist=list()
HH=matrix(0,llmd,llmd)

for(i in 1: n)
{

Ti=matrix(0,M[i],M[i])
for(j in 2:M[i])
{
for(k in 1:(j-1))
{
Ti[j,k]=-W[i,j,k,]%*%Gammahat
}
}
Li=Ti
diag(Ti)=rep(1,M[i])
Tlist[[i]]=Ti

EpsilonLamVector=rep(0,M[i])
EpsilonLamVector[1]=Rlist[[i]][1]

for(s in 2:M[i])
{
EpsilonLamVector[s]=Rlist[[i]][s]+t(Li[s,])%*%Rlist[[i]]
}
EpsilonLamlist[[i]]=EpsilonLamVector

fvectoRlist[[i]]=EpsilonLamlist[[i]]^2
HH=HH+(t(Hlist[[i]])%*%Hlist[[i]])
} # end of loop i.

KLam=0
repeat
{
Lamhatold=Lamhatnew
U3=rep(0,llmd)

for(K in 1:n)
{
dli=exp(Hlist[[K]]%*%Lamhatold)
Dli.inv=diag(as.vector(1/dli))

U3=U3+t(Hlist[[K]])%*%(Dli.inv%*%fvectoRlist[[K]]-rep(1,M[K]))
}

Lamhatnew=Lamhatold+solve(HH)%*%U3
KLam=KLam+1
if(sum((Lamhatnew-Lamhatold)^2)<=1e-4|KLam>10){break}
}
Lambdahat=Lamhatnew
#-----------------------------------------------
# Calculation for the Beta 
B=matrix(0,lbta,lbta)
U1=rep(0,lbta)
Sigma.hat.list=list()
Sigma.inv.hat.list=list()

for(i in 1: n)
{
di=exp(Hlist[[i]]%*%Lambdahat)
Di=diag(as.vector(di))
Di.inv=diag(as.vector(1/di))
Sigmai.inv=t(Tlist[[i]])%*%Di.inv%*%Tlist[[i]]
Sigma.inv.hat.list[[i]]=Sigmai.inv
Sigma.hat.list[[i]]=solve(Tlist[[i]],tol=1e-300)%*%Di%*%solve(t(Tlist[[i]]),tol=1e-300)

B=B+t(Xlist[[i]])%*%Sigmai.inv%*%Xlist[[i]]
U1=U1+t(Xlist[[i]])%*%Sigmai.inv%*%(Ylist[[i]]-Mulist[[i]])
} 

betahatnew=betahatold+solve(B)%*%U1
Kbeta=Kbeta+1
if(Kbeta>5){break}
} # The end of while loop.
Betahat=betahatnew
#--------------------------------------------------
CovBetahat=solve(B/n,tol=1e-300)
SE.Beta=sqrt(diag(CovBetahat))/sqrt(n)
Bias.Mean=mean((X%*%(Betahat-BetaTrue))^2);

#--------------------------------------------------
output  <- list(Betahat,Gammahat,Lambdahat,Bias.Mean,SE.Beta,Sigma.hat.list,Sigma.inv.hat.list)
names(output) <- list("Betahat","Gammahat","Lambdahat","Bias.Mean","SE.Beta","Sigma.hat.list","Sigma.inv.hat.list")
return(output)
}







######################################################
# MACF Regression 
######################################################
Reg.MACF<-function(DATA,theta0)
{
Xlist=DATA$Xlist
Ylist=DATA$Ylist
Hlist=DATA$Hlist

Time.matrix=DATA$ObsTimeMatrix
M=DATA$m

n=length(M)

lbta<-ncol(Xlist[[1]])
llmd<-ncol(Hlist[[1]])
lgma<-3
#-----------------------------------------------
W<-array(NA,dim=c(n,maxm.sub,maxm.sub-1,lgma))

for(i in 1:n)
{  
  for(j in 2:M[i])
     {
     for(k in 1:(j-1))
        {
        W[i,j,k,]<-polys(Time.matrix[i,j]-Time.matrix[i,k],lgma)  
        }
     }
}
#-----------------------------------------------OK
# Setup initial values
X=NULL;
Y=NULL;
H=NULL;
for(i in 1:n)
   {  
   X=rbind(X,Xlist[[i]]);
   H=rbind(H,Hlist[[i]]);
   Y=c(Y, Ylist[[i]]);
   }

#setup the initial parameters     
bta0=theta0[1:lbta]
gma0=theta0[(lbta+1):(lbta+lgma)]
lmd0=theta0[(lbta+lgma+1):(lbta+lgma+llmd)]
#--------------------------
betahatold=bta0+0.1
betahatnew=bta0
Lamhatold=lmd0+0.1
Lamhatnew=lmd0
Gamhatold<-gma0-0.1
Gamhatnew<-gma0

Kbeta=0
while(sum((betahatnew-betahatold)^2)>1e-4)
{
betahatold=betahatnew
Lamhatold=Lamhatnew

# Setup the calculation structure.
Rlist=list()
for(i in 1: n){Rlist[[i]]=Ylist[[i]]-Xlist[[i]]%*%betahatold}
#--------------------------
# Calculation for Gamma 
KGam=0
repeat
{
Gamhatold=Gamhatnew

U2=rep(0,lgma)
G=matrix(0,lgma,lgma)
Gi=matrix(0,lgma,lgma)

for(i in 1:n){

Li.Gam=matrix(0,M[i],M[i])
for(j in 2:M[i])
{
for(k in 1:(j-1))
{
Li.Gam[j,k]=W[i,j,k,]%*%Gamhatold
}
}
Ti.Gam=Li.Gam
diag(Li.Gam)=rep(1,M[i])
Di.Gam=diag(as.vector(exp(Hlist[[i]]%*%Lamhatold)))
Di.Gam.inv=diag(as.vector(exp(-Hlist[[i]]%*%Lamhatold)))

Epsilon.Gam.i.Vector=rep(0,M[i])
Epsilon.Gam.i.Vector[1]=Rlist[[i]][1]
for(s in 2:M[i]){Epsilon.Gam.i.Vector[s]=Rlist[[i]][s]-t(Ti.Gam[s,])%*%Epsilon.Gam.i.Vector}
#--------------
Zi_list=list()
Zi_list[[1]]=matrix(0,lgma,M[i])

PEp.i.Ga.matrix=matrix(0,lgma,M[i])

for(j in 2:M[i])
{ 
  PEp.i.Ga.j.vector=rep(0,lgma);
  Zij=matrix(0,lgma,M[i]);
  A=matrix(0,lgma,M[i]);
 
  for(k in 1:(j-1))
     {
      PEp.i.Ga.j.vector=PEp.i.Ga.j.vector-(Epsilon.Gam.i.Vector[k]*W[i,j,k,]+Li.Gam[j,k]*PEp.i.Ga.matrix[,k]) 
      Zij[,(k-1)]=W[i,j,(k-1),];
      #Zij[,(k)]=W[i,j,(k),];
      A=A+solve(Li.Gam,tol=1e-300)[j,k]*Zij;
     }
  PEp.i.Ga.matrix[,j]=PEp.i.Ga.j.vector
  Zij[,(j-1)]=W[i,j,(j-1),]
  Zi_list[[j]]=Zij
  Gi=Gi+(diag(Di.Gam.inv)[j])*((Zi_list[[j]]+A)%*%Di.Gam%*%t((Zi_list[[j]]+A)))
} # end of loop j.

#--------------OK
U2=U2+PEp.i.Ga.matrix%*%Di.Gam.inv%*%Epsilon.Gam.i.Vector
G=G+Gi
} 
# End of loop i
#--------------------------
Gamhatnew=Gamhatold-solve(G)%*%U2
KGam=KGam+1
if(sum((Gamhatnew-Gamhatold)^2)<=1e-4|KGam>50){break}
}
Gammahat=Gamhatnew
#-----------------------------------------------
# Calculation for Lambda 
fvectoRlist=list()
HH=matrix(0,llmd,llmd)

Llist=list()
for(i in 1: n)
{
Li.Lam=matrix(0,M[i],M[i])
for(j in 2:M[i])
{
   for(k in 1:(j-1))
      {
       Li.Lam[j,k]=W[i,j,k,]%*%Gammahat
      }
}
Ti.Lam=Li.Lam
diag(Li.Lam)=rep(1,M[i])
Llist[[i]]=Li.Lam

Epsilon.Lam.i.Vector=rep(0,M[i])
Epsilon.Lam.i.Vector[1]=Rlist[[i]][1]
for(s in 2:M[i]){Epsilon.Lam.i.Vector[s]=Rlist[[i]][s]-t(Ti.Lam[s,])%*%Epsilon.Lam.i.Vector}

fvectoRlist[[i]]=Epsilon.Lam.i.Vector^2
HH=HH+(t(Hlist[[i]])%*%Hlist[[i]])
} # end of loop i.

KLam=0
repeat
{
Lamhatold=Lamhatnew
U3=rep(0,llmd)

for(i in 1:n)
{
Di.Lam.inv=diag(as.vector(exp(-Hlist[[i]]%*%Lamhatold)))
U3=U3+t(Hlist[[i]])%*%(Di.Lam.inv%*%fvectoRlist[[i]]-rep(1,M[i]))
}

Lamhatnew=Lamhatold+solve(HH)%*%U3
KLam=KLam+1
if(sum((Lamhatnew-Lamhatold)^2)<=1e-4|KLam>10){break}
}
Lambdahat=Lamhatnew
#-----------------------------------------------
# Calculation for the Beta 
Sigma.hat.list=list()
Sigma.inv.hat.list=list()

B=matrix(0,lbta,lbta)
U1=rep(0,lbta)

for(i in 1: n)
{
Di=diag(as.vector(exp(Hlist[[i]]%*%Lambdahat)))
Di.inv=diag(as.vector(exp(-Hlist[[i]]%*%Lambdahat)))

Sigmai=Llist[[i]]%*%Di%*%t(Llist[[i]])
Sigma.hat.list[[i]]=Sigmai
Sigmai.inv=t(solve(Llist[[i]],tol=1e-300))%*%Di.inv%*%solve(Llist[[i]],tol=1e-300)
Sigma.inv.hat.list[[i]]=Sigmai.inv

B=B+t(Xlist[[i]])%*%Sigmai.inv%*%Xlist[[i]]
U1=U1+t(Xlist[[i]])%*%Sigmai.inv%*%Rlist[[i]]
} 

betahatnew=betahatold+solve(B)%*%U1
Kbeta=Kbeta+1
if(Kbeta>5){break}
} # The end of while loop.
Betahat=betahatnew
#--------------------------------------------------
CovBetahat=solve(B/n,tol=1e-300)
SE.Beta=sqrt(diag(CovBetahat))/sqrt(n)
Bias.Mean=mean((X%*%(Betahat-BetaTrue))^2);
#--------------------------------------------------
output  <- list(Betahat,Gammahat,Lambdahat,Bias.Mean,SE.Beta,Sigma.hat.list,Sigma.inv.hat.list)
names(output) <- list("Betahat","Gammahat","Lambdahat","Bias.Mean","SE.Beta","Sigma.hat.list","Sigma.inv.hat.list")
return(output)
}





######################################################
# HSCF Regression 
######################################################
#first derivative of Tijk w.r.t gamma
Tijk.dev<-function(i,j,k,phi,Ti,W)
  { lgma<-3
     
    if(k<j){
      if(k==1) rlt<--Ti[j,k]*tan(phi[j,k])*W[i,j,k,]
      else {
       aa<-W[i,j,1:(k-1),]/tan(phi[j,1:(k-1)])
      if(!is.matrix(aa)) aa<-t(aa)
      
       rlt<--Ti[j,k]*tan(phi[j,k])*W[i,j,k,]+Ti[j,k]*apply(aa,2,sum)
      }}
    else if(k==j & j>1){
       aa<-W[i,j,1:(k-1),]/tan(phi[j,1:(k-1)])
       if(!is.matrix(aa)) aa<-t(aa)
       
       rlt<-Ti[j,k]*apply(aa,2,sum)
    }
    else  
       rlt<-rep(0,lgma)
 
       return(rlt)
   }
   
 
#first derivative of t(Ti) w.r.t gamma
Tdev<-function(i,Ti,phi,W)
  {
    mi<-nrow(Ti)
    d<-3
    Dev<-matrix(0,d*mi,mi)
    for(k in 2:mi)
       for(j in 1:k)
          Dev[((j-1)*d+1):((j-1)*d+d),k]<-Tijk.dev(i,k,j,phi,Ti,W)
    return(Dev)
}

######################################################
HSCF.likfun<-function(theta,m,Ylist,Xlist,Hlist,W){

    n<-length(m)
    lbta<-ncol(Xlist[[1]])
    llmd<-ncol(Hlist[[1]])
    lgma<-3

    bta<-theta[1:lbta]
    gma<-theta[(lbta+1):(lbta+lgma)]
    lmd<-theta[(lbta+lgma+1):(lbta+lgma+llmd)]    
       
    lik<-0 
#----------------------------------------    
   for(i in 1:n)
  {
   #compute Ti at gma
   Ti<-phi<-matrix(0,m[i],m[i])
   Ti[1,1]<-1
     if(m[i]>1){
      for(j in 2:m[i])
       { for(k in 1:(j-1))
             phi[j,k]<-W[i,j,k,]%*%gma      
             
         Ti[j,j]<-prod(sin(phi[j,1:(j-1)]))
         Ti[j,1]<-cos(phi[j,1])
         if(j>2)
           {
           for(l in 2:(j-1)) 
             Ti[j,l]<-cos(phi[j,l])*prod(sin(phi[j,1:(l-1)]))   
           }
        }
     }
      di<-drop(exp(Hlist[[i]]%*%lmd/2))      
      Di<-matrix(0,m[i],m[i]) 
      diag(Di)<-di
      Sigmai<-Di%*%Ti%*%t(Ti)%*%Di
      Di.inv<-Di
      diag(Di.inv)<-1/di
      Ti.inv<-solve(Ti,tol=1e-1000)
      Sigmai.inv<-Di.inv%*%t(Ti.inv)%*%Ti.inv%*%Di.inv
      ri<-drop(Ylist[[i]]-Xlist[[i]]%*%bta)
      log.detSigmai<-2*sum(log(di))+2*sum(log(abs(diag(Ti))))     
      lik<-lik+(log.detSigmai+t(ri)%*%Sigmai.inv%*%ri)   
}
#---------------------------------------- 
  return(lik)
}
######################################################
Reg.HSCF<-function(DATA,theta0)
{
Xlist=DATA$Xlist
Ylist=DATA$Ylist
Hlist=DATA$Hlist

Time.matrix=DATA$ObsTimeMatrix
M=DATA$m

n=length(M)

lbta<-ncol(Xlist[[1]])
llmd<-ncol(Hlist[[1]])
lgma<-3
#-----------------------------------------------
W<-array(NA,dim=c(n,maxm.sub,maxm.sub-1,lgma))

for(i in 1:n)
{  
  for(j in 2:M[i])
     {
     for(k in 1:(j-1))
        {
        W[i,j,k,]<-polys(Time.matrix[i,j]-Time.matrix[i,k],lgma)  
        }
     }
}
#-----------------------------------------------OK
# Setup initial values
X=NULL;
Y=NULL;
H=NULL;
for(i in 1:n)
   {  
   X=rbind(X,Xlist[[i]]);
   H=rbind(H,Hlist[[i]]);
   Y=c(Y, Ylist[[i]]);
   }

#setup the initial parameters     
bta0=theta0[1:lbta]
gma0=theta0[(lbta+1):(lbta+lgma)]
lmd0=theta0[(lbta+lgma+1):(lbta+lgma+llmd)]
#-----------------------------------------------OK
    th<-c(bta0,gma0,lmd0)
    HSCF.Results<-ucminf(th,HSCF.likfun,m=M,Ylist=Ylist,Xlist=Xlist,Hlist=Hlist,W=W
                        ,control=list( grtol=1e-4, maxeval=100));

    Betahat <- HSCF.Results$par[1:lbta]
    Gammahat<- HSCF.Results$par[(lbta+1):(lbta+lgma)]
    Lambdahat<-HSCF.Results$par[(lbta+lgma+1):(lbta+lgma+llmd)]     
#-----------------------------------------------OK
Sigma.hat.list=list()
B=matrix(0,lbta,lbta)
Sigma.inv.hat.list=list()

   for(i in 1:n)
  {
   Ti.hat<-phi.hat<-matrix(0,M[i],M[i])
   Ti.hat[1,1]<-1
     if(M[i]>1){
      for(j in 2:M[i])
       { for(k in 1:(j-1))

         phi.hat[j,k]<-W[i,j,k,]%*%Gammahat
             
         Ti.hat[j,j]<-prod(sin(phi.hat[j,1:(j-1)]))
         Ti.hat[j,1]<-cos(phi.hat[j,1])
         if(j>2)
           {
           for(l in 2:(j-1)) 
             Ti.hat[j,l]<-cos(phi.hat[j,l])*prod(sin(phi.hat[j,1:(l-1)]))   
           }
        }
     }
      di.hat<-drop(exp(Hlist[[i]]%*%Lambdahat/2))      
      Di.hat<-matrix(0,M[i],M[i]) 
      diag(Di.hat)<-di.hat
      Sigmai.hat<-Di.hat%*%Ti.hat%*%t(Ti.hat)%*%Di.hat
      Sigma.hat.list[[i]]=Sigmai.hat

      Di.inv.hat<-matrix(0,M[i],M[i])
      diag(Di.inv.hat)<-1/di.hat
      Ti.inv.hat<-solve(Ti.hat,tol=1e-300)
      Sigmai.inv.hat<-Di.inv.hat%*%t(Ti.inv.hat)%*%Ti.inv.hat%*%Di.inv.hat
      Sigma.inv.hat.list[[i]]=Sigmai.inv.hat
      B=B+t(Xlist[[i]])%*%Sigmai.inv.hat%*%Xlist[[i]]
   }

#--------------------------------------------------
CovBetahat=solve(B/n,tol=1e-300)
SE.Beta=sqrt(diag(CovBetahat))/sqrt(n)
Bias.Mean=mean((X%*%(Betahat-BetaTrue))^2);

#--------------------------------------------------
output  <- list(Betahat,Gammahat,Lambdahat,Bias.Mean,SE.Beta,Sigma.hat.list,Sigma.inv.hat.list)
names(output) <- list("Betahat","Gammahat","Lambdahat","Bias.Mean","SE.Beta","Sigma.hat.list","Sigma.inv.hat.list")
return(output)
}










###############################################
# Regression of Combining Likelihood model.
###############################################
CML.likfun<-function(theta,Xlist,Ylist,Sigma.inv_2_list,Sigma.inv_3_list,Sigma.inv_4_list)
{

n=length(Ylist)
lbta<-ncol(Xlist[[1]])
BetaCMLhat<-theta
#----------------------------------------------
# Setup the calculation structure.
g_2_list=list()
g_3_list=list()
g_4_list=list()

for(i in 1:n)
{
g_2_list[[i]]=t(as.matrix(Xlist[[i]]))%*%Sigma.inv_2_list[[i]]%*%(as.vector(Ylist[[i]])-as.matrix(Xlist[[i]])%*%BetaCMLhat)
g_3_list[[i]]=t(as.matrix(Xlist[[i]]))%*%Sigma.inv_3_list[[i]]%*%(as.vector(Ylist[[i]])-as.matrix(Xlist[[i]])%*%BetaCMLhat)
g_4_list[[i]]=t(as.matrix(Xlist[[i]]))%*%Sigma.inv_4_list[[i]]%*%(as.vector(Ylist[[i]])-as.matrix(Xlist[[i]])%*%BetaCMLhat)
}
BGmatrix=matrix(0,3*lbta, n)
for(i in 1:n)
{
BGmatrix[,i]=c(g_2_list[[i]],g_3_list[[i]],g_4_list[[i]])
}
#----------------------------------------------
# This part is used to calcutlate the Lagrange multilier vector T
T1D=matrix(0,3*lbta,1)
T2D=matrix(0,3*lbta,3*lbta)
Tvectorold=rep(0,(3*lbta))+0.1
Tvectornew=rep(0,(3*lbta))

KTvecor=0 
IndexTest=NULL
while((sum((Tvectornew-Tvectorold)^2)>1e-4) )
{
Tvectorold=Tvectornew

for(a in 1:n)
{
T1D=T1D+BGmatrix[,a]/as.numeric(1+t(Tvectorold)%*%BGmatrix[,a])
T2D=T2D+(BGmatrix[,a]%*%t(BGmatrix[,a]))/as.numeric((1+t(Tvectornew)%*%BGmatrix[,a])^2)
}
Tvectornew=Tvectorold+solve(T2D,tol=1e-300)%*%T1D

IndexTest=NULL
for(S in 1:n){IndexTest=c(IndexTest,((1+t(Tvectornew)%*%BGmatrix[,S])>=(1/n)))}

KTvecor=KTvecor+1
if(KTvecor>100){break}
} # End of while loop.
Tvectoruse=Tvectornew
#----------------------------------------------
CML.lik<-0
for(S in 1:n){ 
CML.lik=ifelse( IndexTest[S] ,CML.lik+log((1+t(Tvectoruse)%*%BGmatrix[,S])), CML.lik )
}
#----------------------------------------------
return(CML.lik)
}
###############################################
CML.Est <- function(DATA,theta0)
{
Xlist=DATA$Xlist
Ylist=DATA$Ylist
Hlist=DATA$Hlist
Time.matrix=DATA$ObsTimeMatrix
Sigma.True.list=DATA$Sigma.true.list

M=DATA$m

n=length(M)
p=ncol(Xlist[[1]])
d=ncol(Hlist[[1]])
q=3
#----------------------------------------------
Result.MCDF<-Reg.MCDF(DATA,theta0)
Betahat.MCDF=Result.MCDF$Betahat
SEBeta.MCDF=Result.MCDF$SE.Beta
BiasMean.MCDF=Result.MCDF$Bias.Mean
Sigma.inv_MCDF_list=Result.MCDF$Sigma.inv.hat.list
#----------------------------------------------
Result.MACF<-Reg.MACF(DATA,theta0)
Betahat.MACF=Result.MACF$Betahat
SEBeta.MACF=Result.MACF$SE.Beta
BiasMean.MACF=Result.MACF$Bias.Mean
Sigma.inv_MACF_list=Result.MACF$Sigma.inv.hat.list
#----------------------------------------------
Result.HSCF<-Reg.HSCF(DATA,theta0)
Betahat.HSCF=Result.HSCF$Betahat
SEBeta.HSCF=Result.HSCF$SE.Beta
BiasMean.HSCF=Result.HSCF$Bias.Mean
Sigma.inv_HSCF_list=Result.HSCF$Sigma.inv.hat.list
#----------------------------------------------
# Setup initial values
X=NULL;
Y=NULL;
H=NULL;

for(i in 1:n)
   {  
   X=rbind(X,Xlist[[i]]);
   H=rbind(H,Hlist[[i]]);
   Y=c(Y, Ylist[[i]]);
   }

bta0=theta0[1:p]
gma0=theta0[(p+1):(p+q)]
lmd0=theta0[(p+q+1):(p+q+d)]
#----------------------------------------------
th=bta0
CML.Result<-ucminf(th,CML.likfun,Xlist=Xlist,Ylist=Ylist,Sigma.inv_2_list=Sigma.inv_MCDF_list,Sigma.inv_3_list=Sigma.inv_MACF_list,Sigma.inv_4_list=Sigma.inv_HSCF_list
 ,control=list(maxeval=50));

BetahatCML=CML.Result$par
#----------------------------------------------
# This part is used to calculate the SE of CMLE.
v_2=matrix(0,p,p)
v_3=matrix(0,p,p)
v_4=matrix(0,p,p)
V22=matrix(0,3*p,3*p)

for(i in 1:n)
{
v_2=v_2-t(Xlist[[i]])%*%Sigma.inv_MCDF_list[[i]]%*%Xlist[[i]]
v_3=v_3-t(Xlist[[i]])%*%Sigma.inv_MACF_list[[i]]%*%Xlist[[i]]
v_4=v_4-t(Xlist[[i]])%*%Sigma.inv_HSCF_list[[i]]%*%Xlist[[i]]

g_2=t(as.matrix(Xlist[[i]]))%*%Sigma.inv_MCDF_list[[i]]%*%(as.vector(Ylist[[i]])-as.matrix(Xlist[[i]])%*%BetahatCML)
g_3=t(as.matrix(Xlist[[i]]))%*%Sigma.inv_MACF_list[[i]]%*%(as.vector(Ylist[[i]])-as.matrix(Xlist[[i]])%*%BetahatCML)
g_4=t(as.matrix(Xlist[[i]]))%*%Sigma.inv_HSCF_list[[i]]%*%(as.vector(Ylist[[i]])-as.matrix(Xlist[[i]])%*%BetahatCML)

Bi=c(g_2,g_3,g_4)

V22=V22+Bi%*%t(Bi)/n
}
V12=rbind(v_2,v_3,v_4)/n

VarBetahatCML=solve(t(V12)%*%solve(V22,tol=1e-300)%*%V12,tol=1e-300)
SEBetahatCML=sqrt(diag(VarBetahatCML))/sqrt(n)
BiasMeanCML=mean((X%*%(BetahatCML-BetaTrue))^2);
#-----------------------------------------------
output  <- list(BetahatCML,SEBetahatCML,BiasMeanCML,Betahat.MCDF,SEBeta.MCDF,BiasMean.MCDF,Betahat.MACF,SEBeta.MACF,BiasMean.MACF,Betahat.HSCF,SEBeta.HSCF,BiasMean.HSCF)
names(output)<- list("BetahatCML","SEBetahatCML","BiasMeanCML","Betahat.MCDF","SEBeta.MCDF","BiasMean.MCDF","Betahat.MACF","SEBeta.MACF","BiasMean.MACF","Betahat.HSCF","SEBeta.HSCF","BiasMean.HSCF")
return(output)
}









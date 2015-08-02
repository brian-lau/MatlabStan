data {
  int<lower=0> p;
  int<lower=0> N;
  int<lower=0,upper=1> y[N];
  matrix[N,p] x;
}
transformed data {
  matrix[N,p] z;
  vector[p] mean_x;
  vector[p] sd_x;
  for (j in 1:p) { 
    mean_x[j] <- mean(col(x,j)); 
    sd_x[j] <- sd(col(x,j)); 
    for (i in 1:N)
      z[i,j] <- (x[i,j] - mean_x[j]) / sd_x[j]; 
  }
}
parameters {
  real beta0;
  vector[p] beta;
  real<lower=0> phi;
}
model {
  vector[N] eta;
  eta <- beta0 + z*beta;
  beta ~ normal(0, phi);
  phi ~ double_exponential(0, 10);
  y ~ bernoulli_logit(eta);
}
generated quantities {
  vector[N] log_lik;
  vector[N] eta;
  eta <- beta0 + z*beta;
  for (i in 1:N)
    log_lik[i] <- bernoulli_logit_log(y[i],eta[i]);
}

#seed value for random vectors
x<-10

#create random vectors
y<-rnorm(x)
z<-rnorm(x)

#create a dataframe
df<-data.frame(z,y)

#run a regression
model<-lm(df$z~df$y)

#display output
print(summary(model))
plot(model)


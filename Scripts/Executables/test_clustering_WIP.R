
kmeans(archetypeMetricsDf$Presence, centers = 4, algorithm = "Hartigan-Wong")
kmeans(archetypeMetricsDf$Presence, centers = 4, algorithm = "Lloyd")
kmeans(archetypeMetricsDf$Presence, centers = 4, algorithm = "Forgy")
kmeans(archetypeMetricsDf$Presence, centers = 4, algorithm = "MacQueen")

library(NbClust)
NbClust(archetypeMetricsDf$Presence, method = 'complete', index = 'all')$Best.nc

sort(kmeans(archetypeMetricsDf$Presence, centers = 9, algorithm = "Hartigan-Wong")$centers)
sort(kmeans(archetypeMetricsDf$Presence, centers = 9, algorithm = "Lloyd")$centers)
sort(kmeans(archetypeMetricsDf$Presence, centers = 9, algorithm = "Forgy")$centers)
sort(kmeans(archetypeMetricsDf$Presence, centers = 9, algorithm = "MacQueen")$centers)

HWClusterPresence = kmeans(archetypeMetricsDf$Presence, centers = 9, algorithm = "Hartigan-Wong")
HWClusterPresence
clusterDF = data.frame(HWClusterPresence$centers, HWClusterPresence$size)
clusterDF <- clusterDF[order(clusterDF$HWClusterPresence.centers,decreasing=TRUE),]
clusterDF

boxplot(archetypeMetricsDf$Presence,
        ylab = "Presence"
)
sort(boxplot.stats(archetypeMetricsDf$Presence)$out)
mean(archetypeMetricsDf$Presence)
quantile(archetypeMetricsDf$Presence, 0.90)
quantile(archetypeMetricsDf$Presence, 0.95)
quantile(archetypeMetricsDf$Presence, 0.975)
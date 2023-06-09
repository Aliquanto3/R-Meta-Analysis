################################################################################
#####                  MTG Tournament Result Analysis                      #####
#####                           by Anaël Yahi                              #####
#####               based on data generated by Phelps-san                  #####
#####            https://github.com/Badaro/MTGOArchetypeParser             #####
################################################################################
#####                      02-Metagame_Data_Treatment.R                    #####
##### Use this file to import functions that will provide the classical    #####
##### metagame analysis metrics.                                           #####
################################################################################

library(dplyr) 
library(tidyverse)

# # For development
# df = tournamentDf
# chartShare = ChartShare
# presence = "Matches"
# beginning = Beginning
# end = End
# eventType = EventType
# mtgFormat = MtgFormat
# statShare = StatShare
# archetype = "Omnath Scapeshift"

#' List of all the different archetypes in the data
#'
#' @param df the dataframe generated by generate_df()
#'
#' @return a 1-column dataframe with the list of archetypes in the dataset
#' @export
#'
#' @examples
generate_archetype_list = function(df){
  archetype_list=data.frame(unique(df$Archetype$Archetype))
  names(archetype_list)[1] = c("Archetype")
  return(archetype_list)
}

#' Get the presence of a given archetype
#'
#' @param df the dataframe generated by generate_df() 
#' @param archetypeName a string, the name of the archetype you are looking for
#' @param presence the definition of metagame presence (aka share) to use. 
#' It can be:
#' - "Copies": the number of lines in the dataframe dedicated to that archetype
#' - "Players": the number of different players piloting that archetype
#' - "Matches": the number of matches played by the archetype
#'
#' @return an integer, the value of the presence by the chosen metric
#' @export
#'
#' @examples
get_archetype_presence = function(df,archetypeName,presence){
  df2=df[df$Archetype$Archetype==archetypeName,]
  
  return(ifelse(presence=="Copies",nrow(df2),
                                 ifelse(presence=="Players",
                                        length(unique(df2$Player)),
                                        ifelse(presence=="Matches",
                                               sum(df2$NRounds,df2$T8Matches),
                                               NA))))
}

#' Get the metagame presence (aka share) of each archetype
#'
#' @param df the dataframe generated by generate_df() 
#' @param statShare the value of the cut to be set in "Others" for an archetype.
#' It must be a numeric value. For a cut at 2%, use statShare=2 (not 0.02).
#' @param presence the definition of metagame presence (aka share) to use. 
#' It can be:
#' - "Copies": the number of lines in the dataframe dedicated to that archetype
#' - "Players": the number of different players piloting that archetype
#' - "Matches": the number of matches played by the archetype
#'
#' @return
#' @export
#'
#' @examples
generate_metagame_data = function(df,statShare,presence){
  
  archetype_list=generate_archetype_list(df)
  
  #Add the presence of each archetype in the data
  archetype_list$Presence = 
    sapply(X = archetype_list$Archetype, 
           FUN = get_archetype_presence, 
           df = df, presence = presence)
  
  # Aggregate all the archetypes accounting for less than statShare % of the 
  # presence in the dataset
  graph_treshold = statShare/100*sum(archetype_list$Presence)
  main_archetype_list = arrange(archetype_list[
    archetype_list$Presence >= graph_treshold, ],desc(Presence))
  
  # Add an "Other" category aggregating the presence of archetypes under 
  # statShare %
  presence_other = sum(archetype_list[archetype_list$Presence < 
                                        graph_treshold, ]$Presence)
  if(presence_other>0){
    otherName = paste("Other (each <",statShare,"%)",sep="")
    main_archetype_list = rbind(main_archetype_list, 
                                data.frame(Archetype = otherName, 
                                           Presence = presence_other))
  }
  
  # Add the metagame share as % in the dataframe
  main_archetype_list$Share = 
    as.numeric(format(round(
      main_archetype_list$Presence/sum(main_archetype_list$Presence)*100,
                                              1), nsmall = 1))
  
  # Force an order for the archetypes, with Other as the last one
  # (useful for ggplot)
  main_archetype_list$Archetype = reorder(main_archetype_list$Archetype, 
                                    as.numeric(main_archetype_list$Presence))
  if(presence_other>0){
    main_archetype_list$Archetype = 
      relevel(main_archetype_list$Archetype, otherName)
  }
  main_archetype_list$Archetype=fct_rev(main_archetype_list$Archetype)
  
  return(main_archetype_list)
}

#' Table of the presence and win rate by archetype
#'
#' @param df the dataframe generated by generate_df()  
#'
#' @return a dataframe with 9 colums and one row by archetype.
#' 1 column for the archetypes.
#' 3 columns for the presence (number of copies, number of players, number of
#' matches).
#' 3 columns for the win rate (the measured one and the lower and upper bounds
#' of the 95% confidence interval of the win rate).
#' @export
#'
#' @examples
archetype_metrics = function(df){
  #GET THE LIST OF THE DIFFERENT ARCHETYPES IN THE DATA
  metric_df = generate_archetype_list(df)
  
  metric_df$Copies = sapply(X = metric_df$Archetype, 
                              FUN = function(archetype, df) {
                                nrow(df[df$Archetype$Archetype == archetype,])
                              }, df)
  metric_df$Players = sapply(X = metric_df$Archetype, 
                             FUN = function(archetype, df) {
                               length(unique(df[df$Archetype$Archetype == 
                                                  archetype,]$Player))
                             }, df)
  metric_df$Wins = sapply(X = metric_df$Archetype, 
                           FUN = function(archetype, df) {
                             sum(df[df$Archetype$Archetype == 
                                      archetype,]$NWins)
                           }, df)
  metric_df$Defeats = sapply(X = metric_df$Archetype, 
                              FUN = function(archetype, df) {
                                sum(df[df$Archetype$Archetype == 
                                         archetype,]$NDefeats)
                              }, df)
  metric_df$Draws = sapply(X = metric_df$Archetype, 
                            FUN = function(archetype, df) {
                              sum(df[df$Archetype$Archetype == 
                                       archetype,]$NDraws)
                            }, df)
  metric_df$Matches = metric_df$Wins + metric_df$Draws + metric_df$Defeats
  
  metric_df$MeasuredWinrate = metric_df$Wins * 100 / 
    (metric_df$Wins + metric_df$Defeats)
  
  metric_df$CI95LowerBound = mapply(FUN = function(wins, defeats){
    binom.test(wins, wins + defeats, p = 0.5, alternative = "two.sided", 
               conf.level = CIPercent)$conf.int[1] * 100
  }, metric_df$Wins, metric_df$Defeats)
  
  metric_df$CI95UpperBound =  mapply(FUN = function(wins, defeats){
    binom.test(wins, wins + defeats, p = 0.5, alternative = "two.sided", 
               conf.level = CIPercent)$conf.int[2] * 100
  }, metric_df$Wins, metric_df$Defeats)
  
  return(metric_df)
}

#' Normalized sum of presence and win rate
#'
#' @param metric_df the dataframe generated by archetype_metrics()  
#' @param presence the definition of metagame presence (aka share) to use. 
#' It can be:
#' - "Copies": the number of lines in the dataframe dedicated to that archetype
#' - "Players": the number of different players piloting that archetype
#' - "Matches": the number of matches played by the archetype
#'
#' @return a dataframe adding four columns to the input: 
#'  - the normalized input presence 
#'  - the normalized win rate 
#'  - the sum of the normalized presence and win rate
#'  - the rank based on that sum.
#' @export
#'
#' @examples
archetype_ranking = function(archetypeMetricsDf,presence){
  
  # Make the values of both metrics start at 0 by subtracting the minimum value
  metric_df_start_at_0 = archetypeMetricsDf
  
  # Use the logarithm of the presence
  # It usually has an exponential distribution, make it linear
  metric_df_start_at_0$NormalizedPresence = 
    unlist(log(metric_df_start_at_0[presence]) - 
    log(min(metric_df_start_at_0[presence])))
  
  metric_df_start_at_0$NormalizedMeasuredWinrate = 
    metric_df_start_at_0$MeasuredWinrate -
    min(metric_df_start_at_0$MeasuredWinrate)
  
  # Make the values of both metrics go up to 1 by dividing by the maximum value
  metric_df_between_0_and_1 = metric_df_start_at_0
  
  metric_df_between_0_and_1$NormalizedPresence = 
    metric_df_between_0_and_1$NormalizedPresence / 
    max(metric_df_between_0_and_1$NormalizedPresence)
  
  metric_df_between_0_and_1$NormalizedMeasuredWinrate = 
    metric_df_between_0_and_1$NormalizedMeasuredWinrate / 
    max(metric_df_between_0_and_1$NormalizedMeasuredWinrate)
  
  # We now have normalized metrics we can sum
  metric_df_normalized=metric_df_between_0_and_1
  metric_df_normalized$NormalizedSum = 
    metric_df_normalized$NormalizedPresence + 
    metric_df_normalized$NormalizedMeasuredWinrate
  
  # Order the rows based on the decreasing ranking according to that 
  # normalized sum
  metric_df_normalized = 
    metric_df_normalized[order(
      metric_df_normalized$NormalizedSum,decreasing=TRUE),]
  
  metric_df_normalized$Rank = (1:nrow(metric_df_normalized))
  
  return(metric_df_normalized)
}

#' Tier list data
#'
#' @param archetypeRankingDf the dataframe generated by archetype_ranking()
#' @param presence the definition of metagame presence (aka share) to use. 
#' It can be:
#' - "Copies": the number of lines in the dataframe dedicated to that archetype
#' - "Players": the number of different players piloting that archetype
#' - "Matches": the number of matches played by the archetype
#' @param statShare the value of the cut to be set in "Others" for an archetype.
#' It must be a numeric value. For a cut at 2%, use statShare = 2 (not 0.02).
#'
#' @return an updated dataframe keeping only the most present decks and adding a
#' tiers column.
#' @export
#'
#' @examples
archetype_tiers = function(archetypeRankingDf, presence, statShare){
  
  # Add a presence column and scale it with the win rate up to 100 
  archetypeRankingDf$Presence = 100 * unlist(archetypeRankingDf[presence]) / 
    sum(unlist(archetypeRankingDf[presence]))
  archetypeRankingDf$MeasuredWinrate = archetypeRankingDf$MeasuredWinrate
  
  # Keep only the most present archetypes 
  presence_min = statShare / 100 * sum(archetypeRankingDf$Presence)
  tier_archetypes = 
    archetypeRankingDf[archetypeRankingDf$Presence >= presence_min,]
  
  meanMetric = mean(tier_archetypes$NormalizedSum)
  sdMetric = sd(tier_archetypes$NormalizedSum)
  
  tier_archetypes = tier_archetypes %>% 
    mutate(Tiers = case_when(
      NormalizedSum >= meanMetric + 3 * sdMetric ~ "0",
      NormalizedSum >= meanMetric + 2 * sdMetric ~ "0.5",
      NormalizedSum >= meanMetric + 1 * sdMetric ~ "1",
      NormalizedSum >= meanMetric ~ "1.5",
      NormalizedSum >= meanMetric - 1 * sdMetric ~ "2",
      NormalizedSum >= meanMetric - 2 * sdMetric ~ "2.5",
      NormalizedSum >= meanMetric - 3 * sdMetric ~ "3",
      TRUE ~ "Other"
    )
    )
}

#' Matchup data of the most present archetypes
#'
#' @param df the dataframe generated by generate_df() 
#' @param chartShare the value of the cut to be set in "Others" for an archetype.
#' It must be a numeric value. For a cut at 2%, use statShare=2 (not 0.02).
#' @param presence the definition of metagame presence (aka share) to use. 
#' It can be:
#' - "Copies": the number of lines in the dataframe dedicated to that archetype
#' - "Players": the number of different players piloting that archetype
#' - "Matches": the number of matches played by the archetype
#' @param archetype NA by default. If NA, generate a NxN matchup matrix.
#' Otherwise, if a string with an archetype name is given, return a single row,
#' for the matchups against the most played decks of the chosen archetype.
#'
#' @return a dataframe with multiple rows by archetype, one for each matchup.
#' Used for building the matchup matrix. Cut done by chartShare, with a maximum
#' of 18 lines.
#' @export
#'
#' @examples
generate_matchup_data = function(df, chartShare, presence, archetype = NA){
  
  df_gen = generate_metagame_data(df, chartShare, presence)
  # Can only display up to 18 rows before the matrix becomes unreadable
  if(nrow(df_gen) > 18){
    df_other_to_sum = df_gen[18:nrow(df_gen),]
    df_other = data.frame(Archetype = 
                            paste0("Other (each < ",min(df_gen[1:17,]$Share),"%)"), 
                          Presence = sum(df_other_to_sum$Presence), 
                          Share = sum(df_other_to_sum$Share)
                          )
    df_gen = rbind(df_gen[1:17,],df_other)
  }
  
  archetypeList = df_gen$Archetype
  otherName = as.character(tail(archetypeList, n = 1))
  
  win_matrix = ifelse(is.na(archetype),
                      list(matrix(0, ncol = nrow(df_gen), nrow = nrow(df_gen))),
                      list(matrix(0, ncol = nrow(df_gen), nrow = 1)))[[1]]
  
  rownames(win_matrix) = ifelse(is.na(archetype),
                                list(df_gen$Archetype),
                                archetype)[[1]]
  colnames(win_matrix) = df_gen$Archetype
  
  loss_matrix = win_matrix
  match_matrix = win_matrix
  wr_matrix = win_matrix
  wr95Min_matrix = win_matrix
  wr95Max_matrix = win_matrix

  if(is.na(archetype)){
    # Only iterate over rows where we have MU data
    conditionMUNotNull = !sapply(df$Matchups, function(x) length(x) == 0 )
    for (i in (1:nrow(df))[conditionMUNotNull]){
      
      archetype1I = df[i,]$Archetype$Archetype
      archetype1I = ifelse(archetype1I %in% archetypeList,archetype1I,otherName)
      matchesI = df[i,]$Matchups[[1]]
      
      for (j in 1:nrow(matchesI)){
        matchesIJ = matchesI[j,]
        archetype2IJ = matchesIJ$OpponentArchetype
        archetype2IJ = ifelse(archetype2IJ %in% archetypeList,
                              archetype2IJ, otherName)
        
        if(matchesIJ$Wins > matchesIJ$Losses){
          win_matrix[archetype1I, archetype2IJ] = 
            win_matrix[archetype1I, archetype2IJ] + 1
        }else if(matchesIJ$Wins < matchesIJ$Losses){
          loss_matrix[archetype1I, archetype2IJ] = 
            loss_matrix[archetype1I, archetype2IJ] + 1
        }
      }
    }
  }else{
    dfArchetype = df[df$Archetype$Archetype == archetype, ]
    conditionMUNotNull = 
      !sapply(dfArchetype$Matchups, function(x) length(x) == 0 )
    for (i in (1:nrow(dfArchetype))[conditionMUNotNull]){
      
      matchesI = dfArchetype[i,]$Matchups[[1]]
      
      for (j in 1:nrow(matchesI)){
        matchesIJ = matchesI[j,]
        archetype2IJ = matchesIJ$OpponentArchetype
        archetype2IJ = ifelse(archetype2IJ %in% archetypeList,
                              archetype2IJ, otherName)
        
        if(matchesIJ$Wins > matchesIJ$Losses){
          win_matrix[archetype, archetype2IJ] = 
            win_matrix[archetype, archetype2IJ] + 1
        }else if(matchesIJ$Wins < matchesIJ$Losses){
          loss_matrix[archetype, archetype2IJ] = 
            loss_matrix[archetype, archetype2IJ] + 1
        }
      }
    }
  }
  
  match_matrix = win_matrix + loss_matrix
  
  wr_matrix = round(win_matrix/match_matrix*100,digits = 1)
  
  for(i in 1:nrow(wr95Min_matrix)){
    for(j in 1:ncol(wr95Min_matrix)){
      wr95Min_matrix[i,j] = 
        ifelse(match_matrix[i,j] > 0,
               binom.test(win_matrix[i,j], match_matrix[i,j], 
                          p=0.5,alternative="two.sided", 
                          conf.level=CIPercent)$conf.int[1],NA)
    }
  }
  wr95Min_matrix = round(wr95Min_matrix*100,digits = 1)
  
  for(i in 1:nrow(wr95Max_matrix)){
    for(j in 1:ncol(wr95Max_matrix)){
      wr95Max_matrix[i,j] = 
        ifelse(match_matrix[i,j] > 0,
               binom.test(win_matrix[i,j], match_matrix[i,j], 
                          p=0.5,alternative="two.sided", 
                          conf.level=CIPercent)$conf.int[2],NA)
    }
  }
  wr95Max_matrix = round(wr95Max_matrix*100,digits = 1)
  
  arch1Vec = ifelse(is.na(archetype),
    list(rep(colnames(wr_matrix),each=nrow(wr_matrix))),
    archetype)[[1]]
  arch2Vec = rep(colnames(wr_matrix),nrow(wr_matrix)) 
  displayOrder = rep(1:nrow(wr_matrix),each=nrow(wr_matrix)) 
  share = rep(df_gen$Share,each=nrow(wr_matrix)) 
  winRateArch = rep(round(rowSums(win_matrix)/rowSums(match_matrix)*100,digit=1),each=nrow(wr_matrix)) 
  plotTableWR = data.frame(Archetype1 = arch1Vec, 
                           Archetype2 = arch2Vec,
                           MUWinrate = as.vector(t(wr_matrix)),
                           Wins = as.vector(t(win_matrix)),
                           Losses = as.vector(t(loss_matrix)),
                           Matches = as.vector(t(match_matrix)),
                           WR95Min = as.vector(t(wr95Min_matrix)),
                           WR95Max = as.vector(t(wr95Max_matrix)),
                           DisplayOrder = displayOrder,
                           Share = share, WinRateArch = winRateArch)
  plotTableWR$ArchShare1 = paste0("<span style = 'font-size:10pt'><b>",
                                  plotTableWR$Archetype1,"</b></span>",
                                  "<br>Share: ",plotTableWR$Share,
                                  " %<br>Win Rate: ",plotTableWR$WinRateArch,"%")
  plotTableWR$Archetype2 = paste0("vs ",plotTableWR$Archetype2)
  
  plotTableWR$Archetype2 = factor(plotTableWR$Archetype2, 
                                  levels = 
                                    unique(plotTableWR$Archetype2[order(
                                      plotTableWR$DisplayOrder)]), ordered=TRUE)
  
  plotTableWR$OutputText = paste0("<span style = 'font-size:8pt'>",
                                  plotTableWR$WR95Min,"% - ",plotTableWR$WR95Max,
                                  "%</span><br><b>",plotTableWR$MUWinrate,
                                  "%</b><br><span style = 'font-size:8pt'>",
                                  plotTableWR$Matches," matches</span>")
  
  
  return(plotTableWR)
}

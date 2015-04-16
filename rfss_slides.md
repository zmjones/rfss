% Exploratory Data Analysis using Random Forest
% Zachary Jones[^zach] and Fridolin Linder[^frido]


[^zach]:[zmj@zmjones.com](mailto:zmj@zmjones.com)
[^frido]:[fridolin.linder@psu.edu](mailto:fridolin.linder@psu.edu)

# Motivation
 - Exploratory data analysis is important part of every research agenda
 - Rise of ``Big Data'': Lots of data little theory
 - Machine learning is seen as "black box"
 - But can be very helpful, especially when theory is not very developed
 - Random Forest is a flexible, scalable and versatile method to do so 


# Contributions

 - We argue: Predictive algorithms can be used for substantive research (EDA)
 - Introduction to Random Forests for political scientists
 - Collection and exposition of methods for substantive interpretation
 - Developement of an \texttt{R} Package (\texttt{edarf}) to make these methods easily accessible

# Classification and Regression Trees (CART)

 - Random Forest is an ensemble of many CART
 - CART "learns" the model by finding homogeneous subsets of the data conditional on the predictors

![](figures/cart_s.png)


# Random Forests

- CART have low bias high variance and have problems with correlated and weak predictors
- Random Forest (Breiman 2001) solves the problem through:

  1. bagging (resample data, fit a tree to each replicate, summarize over trees)
  2. random selection of predictors at each split

# Random Forest

![The structure of a random forest](figures/concept/concept.png)

# Methods for Exploratory Data Analysis

 - Very good for EDA, because:
     + **Flexible**: Detects interactions, nonlinear relationships
     + **Versatile**: All kinds of outcomes, no parametric assumptions, many predictors
 - But, direct interpretation impossible
 - Special methods to extract substantive insights:
     +  **Variable importance**: permutation importance, average tree depth
     +  Interpreting **relationships**: partial dependence
     +  Detecting **Interactions**: $k$-way partial dependence, depth in Subtrees, marginal vs. joint importance
     +  **Clustering**: proximity matrices

# \texttt{edarf} (**E**xploratory **D**ata **A**nalysis with **R**andom **F**orests)

 - There are three major \texttt{R} packages to fit random forests: \texttt{randomForest}, \texttt{randomForestSRC} and \texttt{party}
 - Methods for interpretation are implemented in some packages, but not consistent across packages
 - No good visualizations (important for EDA)
 - Some newer developments are not integrated (e.g. uncertainty in predictions + see Future Developement)
 - Development version available at: [github.com/zmjones/edarf](http://github.com/zmjones/edarf)

# Example Data

 -  State repression (static, only 1999) country-year data from Fariss (2014) and Hill and Jones (2014)
 -  Field experiment on turnout of ~6000 ex-felons in Connecticut (Gerber et al. 2014)

We are looking for better examples!

# Variable Importance

- Permutation Importance: By how much does the predictive accuracy decrease when randomly permuting an explanatory variable $X$
- Tree depth: How close to the root node is the first split on a variable (Ishwaran 2010)

# Permutation Importance Example

![Permutation importance for predictors of state repression.](figures/latent_imp.png)

# Interpreting Relationships: Partial Dependence

 - Average prediction of the Forest for a value of the predictor

 - Algorithm:
    + Set $X$ to one value of $X$ for each observation in dataset
    + Predict outcome for each observation
    + Average over predictions
    + Repeat for each unique value
    + Plot predictions against unique values of $X$

# Permutation Importance Example

![Partial Dependence for selected predictors of state repression.](figures/latent_pd_slides.png)

# Interaction Detection

- Several methods for interaction detection
    + Joint partial dependence
    + Depth in maximal subtrees
    + Marginal vs. Joint variable importance

# Joint Partial Dependence Example

![Partial dependence of time since release (in years) across treatment levels on the probability of voting in the 2012 election for ex-felons that registered.](figures/pd_int_cond_vote.png)

# Clustering

- Intuitive measure similarity of observations in the predictor space
- How often do two observations end up in the same terminal node:
- Decomposition of proximity matrix ($n \times n$) for visualization

# Clustering Example

![First two principal components of proximity matrix for prisoners example](figures/prox_cond_vote_top.png)

# Future Development

 - functional ANOVA decomposition of learned $f(\mathbf{X})$ (Hooker 2004, 2007)
    + decrease influence of extrapolation of low dimensional representation of learned $f(\mathbf{X})$
 - interaction detection
    + maximal subtree visualization and computation (Ishwaran et. al. 2011)
    + joint/marginal permutation importance visualization and computation
    + additivity testing (Mentch and Hooker 2014)
 - variance estimation
    + using incomplete U-statistics (Mentch and Hooker 2014)

# Future Research (Dependent Data)

 - Nonparametric bootstraps for dependent data (e.g. Lahiri 2003)
    + application specific but would be nice to have accessible implementations
 - GLME estimation random effects and tree-based estimation of $f(\cdot)$ (e.g., Hajjem 2014)

# Conclusion

 - good general purpose supervised learner (in terms of generalization error)
    + empirically (e.g., Fernandez-Delgado et al. 2014)
    + theoretically (e.g., Wager and Walther 2015)
 - many methods for interpretation (compared to many other supervised learners) and `edarf` makes this much easier to do


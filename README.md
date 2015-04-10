This repository contains the code, data, and manuscript for "[Exploratory Data Analysis Using Random Forests](http://zmjones.com/static/papers/rfss_manuscript.pdf)" by [Zachary M. Jones](http://zmjones.com) and [Fridolin Linder](http://polisci.la.psu.edu/people/fjl128).

> The rise of "big data" has made machine learning algorithms more visible and relevant for social scientists, however, they are still widely considered to be "black box" models that are not well suited for substantive research: only prediction. We argue that this need not be the case, and present one method, Random Forests, with an emphasis on practical application for exploratory analysis and substantive interpretation. Random forests detect interaction and nonlinearity without prespecification, have low generalization error in simulations and in many real-world problems, and can be used with many correlated predictors, even when there are more predictors than observations. Importantly, Random Forests can be interpreted in a substantively relevant way with variable importance measures, bivariate and multivariate partial dependence, proximity matrices, and methods for interaction detection. We provide intuition as well as technical detail about how Random Forests work, in theory and in practice, as well as empirical examples from the literature on american and comparative politics. Furthermore, we provide software implementing the methods we discuss to facilitate their use.

The associated software package, which is functional but still under development is [edarf](http://github.com/zmjones/edarf/). Feel free to open issues or issue pull requests. We welcome corrections or suggestions large or small.

To run all of the code use the `Makefile` (assuming you are using a Unix system or have Make installed). If you pass an argument `CORES` the code will be run in parallel.

```{bash}
> make setup
> make code CORES=8
## requires pandoc, pandoc-citeproc and pdflatex to be installed and available in the environment
> make rfss_manuscript.pdf 
```


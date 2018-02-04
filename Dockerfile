FROM rocker/r-base
RUN R -e 'install.packages("plumber", repo = "http://cran.irsn.fr/")'
RUN mkdir /usr/scripts
RUN cd /usr/scripts
COPY plumberfile.R /usr/scripts/plumber.R
COPY torun.R /usr/scripts/torun.R
EXPOSE 8000
CMD Rscript /usr/scripts/torun.R 

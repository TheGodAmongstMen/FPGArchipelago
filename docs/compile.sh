#!/bin/bash

pdflatex SpecTemplate.tex
pdflatex SpecTemplate.tex
rm *.aux *.log *.toc *.out

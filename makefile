all: setup code rfss_manuscript.pdf
code: R/partitioning_example.Rout R/approximation_example.Rout R/hr.Rout R/prisoner.Rout clean

setup:
	R/install_deps.R

rfss_manuscript.pdf: rfss_manuscript.md
	pandoc -H options.sty $< -o $@ --bibliography=rfss.bib
	cp $@ ~/Dropbox/zach_frido/

rfss_manuscript.tex: rfss_manuscript.md
	pandoc -H options.sty $< -o $@ --bibliography=rfss.bib -s

rfss_slides.pdf: rfss_slides.md
	pandoc -t beamer $< -o $@
	cp $@ ~/Dropbox/zach_frido/

R/partitioning_example.Rout: R/partitioning_example.R
	R --no-save --no-restore < $< > $@
	./figures/partition_stitch.sh

R/approximation_example.Rout: R/approximation_example.R
	R --no-save --no-restore < $< > $@

R/hr.Rout: R/hr.R data/eeesr.csv
	R --no-save --no-restore < $< --args $(CORES) > $@

R/prisoner.Rout: R/prisoner.R data/prisoner.csv
	R --no-save --no-restore < $< --args $(CORES) > $@

clean:
	rm R/*.Rout

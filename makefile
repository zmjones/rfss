rfss_manuscript.pdf: rfss_manuscript.md
	pandoc -H options.sty $< -o $@ --bibliography=rfss.bib
	cp $@ ~/Dropbox/zach_frido/

rfss_manuscript.tex: rfss_manuscript.md
	pandoc $< -o $@ --bibliography=rfss.bib -s -V geometry:margin=1.25in

rfss_slides.pdf: rfss_slides.md
	pandoc -t beamer $< -o $@
	cp $@ ~/Dropbox/zach_frido/

interaction_example.Rout: interaction_example.R
	R --no-save --no-restore < $< > $@

partitioning_example.Rout: partitioning_example.R
	R --no-save --no-restore < $< > $@
	source partition_stitch.sh

approximation_example.Rout: approximation_example.R
	R --no-save --no-restore < $< > $@

rf_example.Rout: rf_example.R rf_stitch.sh
	R --no-save --no-restore < $< > $@
	source rf_stitch

hr.Rout: hr.R data/eeesr.csv
	R --no-save --no-restore < $< > $@


rfss_manuscript.pdf: rfss_manuscript.md
	pandoc $< -o $@ --bibliography=rfss.bib -V geometry:margin=1.25in

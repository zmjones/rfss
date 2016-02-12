from __future__ import unicode_literals, print_function, division
import sys
sys.path.append('./text_utils/')
from text_utils import n_grams, CorpusStream, save_sparse_csc # Hand rolled utils
import io
from spacy.en import English
from gensim import corpora, matutils
from nltk.corpus import stopwords
import re

parser = English()

# Generate the cleaned n_gram file
DICT_FILE = 'data/state_bill_dict.pkl'
LABEL_FILE = 'data/state_bill_labels.txt'
TDM_FILE = 'data/state_bill_tdm.npz'
text_input = 'data/state_bills_mallet.txt'
infile = io.open(text_input, 'r', encoding='utf-8')
TEMP_FILE = 'data/state_bill_bigrams.txt'
tempfile = io.open(TEMP_FILE, 'w+', encoding='utf-8')

sw = stopwords.words('english')
excess_space = re.compile(r'\s+')
non_alpha = re.compile(r'[^A-Za-z0-9 ]')

dictionary = corpora.Dictionary()

labels = []

for i, line in enumerate(infile):
    splt = line.split(' ')
    bill_id = splt[0]
    labels.append(bill_id)
    text = ' '.join(splt[2:])
    
    text = non_alpha.sub('', text)
    text = excess_space.sub(' ', text)
    
    bigrams = n_grams(text=text, parser=parser, n=2, stemmer=None, 
                     stopwords=sw, lemmatize=True)
    
    dictionary.doc2bow(bigrams, allow_update=True)
    
    line = ' '.join(bigrams)
    out_line = '{} {}\n'.format(bill_id, line)
    tempfile.write(out_line)
    #if i % 100 == 0:
    #    print(i)
        
infile.close()
tempfile.close()

# Store labels (to have the order)
with io.open(LABEL_FILE, 'w+', encoding='utf-8') as labelfile:
    for label in labels:
	labelfile.write(label + '\n')	

# Reduce dictionary
print('Reducing dictionary')
print(len(dictionary))
dictionary.filter_extremes(no_below=2, no_above=0.9)
print(len(dictionary))
dictionary.save(DICT_FILE)


stream = CorpusStream(dictionary=dictionary, text_input=TEMP_FILE,
                      status=True, use_tfidf=True)
tdm = matutils.corpus2csc(stream, num_terms=len(dictionary), dtype=float, 
                         num_docs=dictionary.num_docs)
print('tdm dimensions:')
print(tdm.shape)
save_sparse_csc(TDM_FILE, tdm)

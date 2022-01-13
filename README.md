# CGN_CL
Supplementary material to the paper "Using Adapters to Overcome Catastrophic Forgetting in End-to-End Automatic Speech Recognition" , submitted at IJCAI 2022. 
This repository is meant to supplement the above paper. It contains the experimental details which should be sufficient to reproduce the results. 

## data ##
As data, we use the Corpus Gesproken Nederlands (CGN) dataset. To obtain a Continual Learning set-up, we split the CGN dataset into four tasks: nl-clean, be-clean, nl-spont, be-spont. Table below provides more information regarding the tasks.


Task  | Dialect | Components | train | dev | test

| ------------- | ------------- | ------------- | ------------- | ------------- | -------------
nl-clean | Netherlands | b;f;g;h;i;k;l;m;n;o | 167k | 3k | 5k 
be-clean | Belgium (Flanders) | b;f;g;h;i;k;l;m;n;o | 136k | 3k | 3k 
nl-spont | Netherlands | a | 239k | 5k | 6k 
be-spont | Belgium (Flanders) | a | 119k | 3k | 5k


For more information regarding the dialect and components, see: https://ivdnt.org/images/stories/producten/documentatie/cgn_website/doc_English/topics/index.htm 

For each task, we have four datasets: training set, dev set, test set and a memory set (to be used by the rehearsal-based methods). The test set is obtained by setting a number of speakers apart; the speakers in the test set do thus not occur in the training set nor dev set. The dev set is obtained by excluding some data from the training set. 

The folder 'data' contains the list of utterances and speakers per dataset, for each of the four tasks.

## model ## 
For the model, we use the ESPnet library. This folder provides the necessary information and files to run an ESPnet model with the same settings as in the paper. 

### wordpieces ### 
In this folder, the files regarding the vocabulary can be found. The vocabulary was generated with the Sentence Piece model on the first task (nl-clean) and consists of approximately 300 word pieces. This same vocabulary was used for all tasks.

### config_files ###
This folder contains the configuration files to be used by ESPnet for training and decoding. In particular, the following configuration files are provided:
- specaug.yaml: configuration for the data augmentation, to be used for training.
- train_cgn250.yaml: configuration file for the training of the initial model (with learning rate of 10.0)
- train_cgn250_ft.yaml: configuration file for the training of a model initialized from a pre-trained model (with learning rate of 1.0)
- decode_cgn250.yaml: configuration for the decoding

### run ### 
This folder contains the run.sh files (recipes) used to run ESPnet, similar to the examples provided by ESPnet (https://github.com/espnet/espnet/tree/master/egs). These recipes consist of 5 stages: (1) data preparation; (2) vocabulary generation; (3) language model training (not used here); (4) training of the model; (5) decoding on a test set. The folder thus contains the following files:
- run_cgn300_stage12.sh: stage 1 and 2 of the recipe.
- run_cgn300_stage4.sh: stage 4 of the recipe.
- run_cgn300_stage5.sh: stage 5 of the recipe. 

## hyper-parameters ##
Finally, we provide some information regarding the hyper-parameters of the Continual Learning methods used in the paper; more specifically, lambda, the weight of the regularization. See the Table below.


Method | Lambda
| :--- | ---:
EWC, A/EWC  | 10^3
LWF  | 10^(-1)
KD, A/KD  | 10^(-1)





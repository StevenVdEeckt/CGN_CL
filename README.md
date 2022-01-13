# CGN_CL
Supplementary material to the paper "Using Adapters to Overcome Catastrophic Forgetting in End-to-End Automatic Speech Recognition" , submitted at IJCAI 2022. 
This repository is meant to supplement the above paper. It contains the experimental details which should be sufficient to reproduce the results. 

### data ###
As data, we use the Corpus Gesproken Nederlands (CGN) dataset. To obtain a Continual Learning set-up, we split the CGN dataset into four tasks: nl-clean, be-clean, nl-spont, be-spont. For each task, we have four datasets: trainset, dev set, test set and a memory set (to be used by the rehearsal-based methods). The folder 'data' contains the list of utterances and speakers per dataset, for each of the four tasks.

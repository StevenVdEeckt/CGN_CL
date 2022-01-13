#!/bin/bash


# Just run them, don't think about it! 
. ./path.sh || exit 1;
. ./cmd.sh || exit 1;
export PATH=.:/users/spraak/spch/prog/spch/ESPnet/kaldi/egs/wsj/s5/utils/parallel:/users/spraak/spch/prog/spch/ESPnet/kaldi/src/featbin:$PATH

# general configuration - important for the next steps
backend=pytorch
stage=4        # start from 0 if you need to start from data preparation
stop_stage=4   # determine when to stop
ngpu=1         # number of gpus ("0" uses cpu, otherwise use gpu)
debugmode=1
dumpdir=dump   # directory to dump full features
exp=exp/cl
N=0            # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
verbose=0      # verbose option
seed=1
exp_tag=""
init=train_nl_bfghijklmno_nl_main_pytorch_uni250
batch_size=16


lang='nl'
comp='a'
task='nl_spont'
transfer_learning=true

# exp tag - related to vocabulary
nbpe=250     # how many subwords?
bpemode=unigram   # unigram or bpe?
tag=uni${nbpe} # tag for managing experiments.

# feature configuration
do_delta=false

# sample filtering
min_io_delta=4  # samples with `len(input) - len(output) * min_io_ratio < min_io_delta` will be removed.

# config files - files for preprocessing, training and decoding
preprocess_config=specaug.yaml  # use conf/specaug.yaml for data augmentation
train_config=train_cgn250.yaml  # this file has initial learning rate of 10.0
if [ ${transfer_learning} = true ]; then
   train_config=train_cgn250_ft.yaml  # if this is not the first task, then use learning rate of 1.0
fi

#lm_config=conf/lm.yaml
decode_config=decode_cgn250.yaml

# decoding parameter
n_average=10 # use 1 for RNN models
recog_model=model.acc.best # set a model to be used for decoding: 'model.acc.best' or 'model.loss.best'

# data - information related to the data
cgn_path=/users/spraak/spchdata/cgn
lang="${lang//;}"
compname="${comp//;}"

# the dictionary and optionally a pre-trained model
dict=data/lang_char/train_nl_bfghijklmno_nl_main_unigram250_units.txt
bpemodel=data/lang_char/train_nl_bfghijklmno_nl_main_unigram250

# Run the following file, don't think about it! 
. utils/parse_options.sh || exit 1;

# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail
unset PYTHONPATH

train_set=train_${lang}_${compname}_${task}
train_dev=dev_${lang}_${compname}_${task}
recog_set=${train_dev}

# Create two dirs, to dump the train and dev features respectively
feat_tr_dir=${dumpdir}/${train_set}/delta${do_delta}; mkdir -p ${feat_tr_dir}
feat_dt_dir=${dumpdir}/${train_dev}/delta${do_delta}; mkdir -p ${feat_dt_dir}

if [ ${transfer_learning} = true ]; then
  expname=${train_set}_transfer_${backend}_${tag}
else
  expname=${train_set}_${backend}_${tag}
fi

expdir=$exp/${expname}${exp_tag}
mkdir -p ${expdir}

pre_trained_model=""
length_init=${#init}
if [ ${length_init} -gt 0 ]; then
   pre_trained_model=/esat/spchtemp/spchdisk_orig/svandere/espnet/asr/exp2/exp/cl/${init}/results/model.last10.avg.best
fi



if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    echo "stage 4: Network Training"

    ${cuda_cmd} --gpu ${ngpu} ${expdir}/train.log \
        CUDA_LAUNCH_BLOCKING=1 asr_train.py \
        --config ${train_config} \
        --preprocess-conf ${preprocess_config} \
        --ngpu ${ngpu} \
        --backend ${backend} \
        --outdir ${expdir}/results \
        --tensorboard-dir tensorboard/${expname}${exp_tag} \
        --debugmode ${debugmode} \
        --dict ${dict} \
        --debugdir ${expdir} \
        --minibatches ${N} \
        --verbose ${verbose} \
        --seed ${seed} \
        --train-json ${train_json} \
        --valid-json ${feat_dt_dir}/data_${bpemode}${nbpe}.json \
        --batch-count seq \
        --batch-size ${batch_size} \
        --dec-init "${pre_trained_model}" \
        --enc-init "${pre_trained_model}" \
        --enc-init-mods encoder. \
        --dec-init-mods decoder. \
        --resume ${resume}
    
fi

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
    echo "stage 5: Decoding"
    nj=32
    if [[ $(get_yaml.py ${train_config} model-module) = *transformer* ]]; then
        recog_model=model.last${n_average}.avg.best
        average_checkpoints.py --backend ${backend} \
                               --snapshots ${expdir}/results/snapshot.ep.* \
                               --out ${expdir}/results/${recog_model} \
                               --num ${n_average}
    fi

    pids=() # initialize pids
    for rtask in ${recog_set}; do
    (
        decode_dir=decode_${rtask}_$(basename ${decode_config%.*})_${lmtag}
        if [ ${lmtag} == "nolm" ]; then
            recog_opts=
        else
          if [ ${use_wordlm} = true ]; then
            recog_opts="--word-rnnlm ${lmexpdir}/rnnlm.model.best"
          else
            recog_opts="--rnnlm ${lmexpdir}/rnnlm.model.best"
          fi
        fi
        feat_recog_dir=${dumpdir}/${rtask}/delta${do_delta}

        # split data
        splitjson.py --parts ${nj} ${feat_recog_dir}/data_${bpemode}${nbpe}.json

        #### use CPU for decoding
        ngpu=0

        ${decode_cmd} JOB=1:${nj} ${expdir}/${decode_dir}/log/decode.JOB.log \
            asr_recog.py \
            --config ${decode_config} \
            --ngpu ${ngpu} \
            --backend ${backend} \
            --recog-json ${feat_recog_dir}/split${nj}utt/data_${bpemode}${nbpe}.JOB.json \
            --result-label ${expdir}/${decode_dir}/data_${bpemode}${nbpe}.JOB.json \
            --model ${expdir}/results/${recog_model}  \
            ${recog_opts}

       # score_sclite.sh --wer true --nlsyms ${nlsyms} ${expdir}/${decode_dir} ${dict}

    ) &
    pids+=($!) # store background pids
    done
    i=0; for pid in "${pids[@]}"; do wait ${pid} || ((++i)); done
    [ ${i} -gt 0 ] && echo "$0: ${i} background jobs are failed." && false
    echo "Finished"
fi

#!/usr/bin/env python
# coding: utf-8

#  # TTM zero-shot and few-shot benchmarking on multiple datasets
# 
#   **Using TTM-512-96 model.**

# ## Imports

# In[1]:


# Standard
import math

# Third Party
from torch.optim import AdamW
from torch.optim.lr_scheduler import OneCycleLR
from transformers import EarlyStoppingCallback, Trainer, TrainingArguments, set_seed
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import os

# First Party
from tsfm_public.toolkit.callbacks import TrackingCallback
from tsfm_public.models.tinytimemixer.utils import (
    count_parameters,
    get_data,
    plot_preds,
)

# Local
from tsfm_public.models.tinytimemixer import TinyTimeMixerForPrediction


# ## Important arguments

# In[2]:


# Set seed
set_seed(42)

# Specify model parameters
context_length = 512
forecast_length = 96
freeze_backbone = True
learning_rate = 0.001

# Other args
EPOCHS = 50
NUM_WORKERS = 16

# Make sure all the datasets in the following `list_datasets` are
# saved in the `DATA_ROOT_PATH` folder. Or, change it accordingly.
# Refer to the get_data() function 
# in notebooks/hfdemo/tinytimemixer/utils/ttm_utils.py 
# to see how it is used.
DATA_ROOT_PATH = "datasets/"

# This is where results will be saved
OUT_DIR = "ttm_results_benchmark_512_96/"


# ## List of benchmark datasets (TTM was not pre-trained on any of these)

# In[3]:


list_datasets = [
    "weather",
    "electricity",
]


# ## Get model path

# In[4]:


hf_model_path = "ibm/TTM"
if context_length == 512:
    hf_model_branch = "main"
elif context_length == 1024:
    hf_model_branch = "1024_96_v1"
else:
    raise ValueError(
        "Current supported context lengths are 512 and 1024. Stay tuned for more TTMs!"
    )


# ## Main benchmarking loop

# In[ ]:


all_results = {
    "dataset": [],
    "zs_mse": [],
    "fs5_mse": [],
    "fs10_mse": [],
    "zs_eval_time": [],
    "fs5_mean_epoch_time": [],
    "fs5_total_train_time": [],
    "fs10_mean_epoch_time": [],
    "fs10_total_train_time": [],
    "fs5_best_val_metric": [],
    "fs10_best_val_metric": [],
}
# Loop over data
for DATASET in list_datasets:
    print()
    print("=" * 100)
    print(
        f"Running zero-shot/few-shot for TTM-{context_length} on dataset = {DATASET}, forecast_len = {forecast_length}"
    )
    print(f"Model will be loaded from {hf_model_path}/{hf_model_branch}")
    SUBDIR = f"{OUT_DIR}/{DATASET}"

    # Set batch size
    if DATASET == "traffic":
        BATCH_SIZE = 8
    elif DATASET == "electricity":
        BATCH_SIZE = 32
    else:
        BATCH_SIZE = 64

    # Data prep: Get dataset
    _, _, dset_test = get_data(DATASET, context_length, forecast_length, data_root_path=DATA_ROOT_PATH)

    #############################################################
    ##### Use the pretrained model in zero-shot forecasting #####
    #############################################################
    # Load model
    zeroshot_model = TinyTimeMixerForPrediction.from_pretrained(
        hf_model_path, revision=hf_model_branch
    )

    # zeroshot_trainer
    zeroshot_trainer = Trainer(
        model=zeroshot_model,
        args=TrainingArguments(
            output_dir=f"{SUBDIR}/zeroshot",
            per_device_eval_batch_size=BATCH_SIZE,
        ),
        eval_dataset=dset_test,
    )

    # evaluate = zero-shot performance
    print("+" * 20, "Test MSE zero-shot", "+" * 20)
    zeroshot_output = zeroshot_trainer.evaluate(dset_test)
    print(zeroshot_output)
    print("+" * 60)
    all_results["zs_eval_time"].append(zeroshot_output["eval_runtime"])

    # Plot
    plot_preds(
        zeroshot_trainer,
        dset_test,
        SUBDIR,
        num_plots=10,
        plot_prefix="test_zeroshot",
        channel=0,
    )
    plt.close()

    # write results
    all_results["dataset"].append(DATASET)
    all_results["zs_mse"].append(zeroshot_output["eval_loss"])

    ################################################################
    ## Use the pretrained model in few-shot 5% and 10% forecasting #
    ################################################################
    for fewshot_percent in [5, 10]:
        print("-" * 20, f"Running few-shot {fewshot_percent}%", "-" * 20)
        # Data prep: Get dataset
        dset_train, dset_val, dset_test = get_data(
            DATASET,
            context_length,
            forecast_length,
            fewshot_fraction=fewshot_percent / 100,
            data_root_path=DATA_ROOT_PATH
        )

        # change head dropout to 0.7 for ett datasets
        if "ett" in DATASET:
            finetune_forecast_model = TinyTimeMixerForPrediction.from_pretrained(
                hf_model_path, revision=hf_model_branch, head_dropout=0.7
            )
        else:
            finetune_forecast_model = TinyTimeMixerForPrediction.from_pretrained(
                hf_model_path, revision=hf_model_branch
            )

        if freeze_backbone:
            print(
                "Number of params before freezing backbone",
                count_parameters(finetune_forecast_model),
            )

            # Freeze the backbone of the model
            for param in finetune_forecast_model.backbone.parameters():
                param.requires_grad = False

            # Count params
            print(
                "Number of params after freezing the backbone",
                count_parameters(finetune_forecast_model),
            )

        print(f"Using learning rate = {learning_rate}")
        finetune_forecast_args = TrainingArguments(
            output_dir=f"{SUBDIR}/fewshot_{fewshot_percent}",
            overwrite_output_dir=True,
            learning_rate=learning_rate,
            num_train_epochs=EPOCHS,
            do_eval=True,
            evaluation_strategy="epoch",
            per_device_train_batch_size=BATCH_SIZE,
            per_device_eval_batch_size=BATCH_SIZE,
            dataloader_num_workers=NUM_WORKERS,
            report_to=None,
            save_strategy="epoch",
            logging_strategy="epoch",
            save_total_limit=1,
            logging_dir=f"{SUBDIR}/fewshot_{fewshot_percent}",  # Make sure to specify a logging directory
            load_best_model_at_end=True,  # Load the best model when training ends
            metric_for_best_model="eval_loss",  # Metric to monitor for early stopping
            greater_is_better=False,  # For loss
        )

        # Create the early stopping callback
        early_stopping_callback = EarlyStoppingCallback(
            early_stopping_patience=10,  # Number of epochs with no improvement after which to stop
            early_stopping_threshold=0.0,  # Minimum improvement required to consider as improvement
        )
        tracking_callback = TrackingCallback()

        # Optimizer and scheduler
        optimizer = AdamW(finetune_forecast_model.parameters(), lr=learning_rate)
        scheduler = OneCycleLR(
            optimizer,
            learning_rate,
            epochs=EPOCHS,
            steps_per_epoch=math.ceil(len(dset_train) / (BATCH_SIZE)),
        )

        finetune_forecast_trainer = Trainer(
            model=finetune_forecast_model,
            args=finetune_forecast_args,
            train_dataset=dset_train,
            eval_dataset=dset_val,
            callbacks=[early_stopping_callback, tracking_callback],
            optimizers=(optimizer, scheduler),
        )

        # Fine tune
        finetune_forecast_trainer.train()

        # Evaluation
        print(
            "+" * 20,
            f"Test MSE after few-shot {fewshot_percent}% fine-tuning",
            "+" * 20,
        )
        fewshot_output = finetune_forecast_trainer.evaluate(dset_test)
        print(fewshot_output)
        print("+" * 60)

        # Plot
        plot_preds(
            finetune_forecast_trainer,
            dset_test,
            SUBDIR,
            num_plots=10,
            plot_prefix=f"test_fewshot_{fewshot_percent}",
            channel=0,
        )
        plt.close()

        # write results
        all_results[f"fs{fewshot_percent}_mse"].append(fewshot_output["eval_loss"])
        all_results[f"fs{fewshot_percent}_mean_epoch_time"].append(
            tracking_callback.mean_epoch_time
        )
        all_results[f"fs{fewshot_percent}_total_train_time"].append(
            tracking_callback.total_train_time
        )
        all_results[f"fs{fewshot_percent}_best_val_metric"].append(
            tracking_callback.best_eval_metric
        )

    pd.set_option('display.max_columns', None)
    pd.set_option('display.max_rows', None)
    pd.set_option('display.max_colwidth', None)

    df_out = pd.DataFrame(all_results).round(3)
    print(df_out[["dataset", "zs_mse", "fs5_mse", "fs10_mse", "zs_eval_time", "fs5_mean_epoch_time", "fs5_total_train_time", "fs10_mean_epoch_time", "fs10_total_train_time", "fs5_best_val_metric", "fs10_best_val_metric"]])
    df_out.to_csv(f"{OUT_DIR}/results_zero_few.csv")


# ## Benchmarking results*
# 
# *Some slight differences in the results as compared to the TTM paper results is possible due to different training environments.

# In[6]:


df_out


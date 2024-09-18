import torch
if torch.cuda.is_available():
    print("CUDA is available. GPU:", torch.cuda.get_device_name(0))
else:
    print("CUDA is not available.")

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

import os
import time
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset, concatenate_datasets


# Load the HumanEval-XL dataset for all languages
print("Loading the HumanEval-XL datasets...")

programming_languages = [
    "python", "go", "java", "javascript", "scala", "csharp",
     "kotlin", "php", "perl", "ruby", "swift", "typescript"
]

datasets = []
   
for programming_language in programming_languages:
    programming_lang_dataset = load_dataset("FloatAI/HumanEval-XL", programming_language, trust_remote_code=True)
    
    concatenated_dataset = concatenate_datasets( [part for part in programming_lang_dataset.values()])
    datasets.append(concatenated_dataset)

combined_dataset = concatenate_datasets(datasets)
print(combined_dataset)

model_name = "Salesforce/codegen-350M-mono"

tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(model_name).to(device)

import re

def generate_code(prompt, model, tokenizer, device, max_new_tokens=200):
    print("in gen code...")

    inputs = tokenizer(prompt, return_tensors="pt").to(device)
    outputs = model.generate(**inputs, max_new_tokens=max_new_tokens, num_return_sequences=1)
    generated_code = tokenizer.decode(outputs[0], skip_special_tokens=True)
    
    # Post-process to keep only the main function and ensure it ends properly
    if "def " in generated_code:
        # Extract the main function including everything after it
        main_function = generated_code.split("def ", 1)[1]
        main_function = "def " + main_function  # Re-add the def keyword
        
        # Detect end of function by finding the next function or end of indentation
        lines = main_function.split('\n')
        function_lines = []
        inside_function = False
        indentation_level = None
        
        for line in lines:
            stripped_line = line.strip()
            if stripped_line.startswith("def ") and inside_function:
                break  # New function starts, stop collecting lines
            if not inside_function:
                if stripped_line.startswith("def "):
                    inside_function = True
                    indentation_level = len(line) - len(line.lstrip())
            if inside_function:
                if stripped_line == "" or line.startswith(" " * indentation_level):
                    function_lines.append(line)
                else:
                    break  # End of the function when the indentation changes

        complete_function = "\n".join(function_lines)
        return complete_function
    return generated_code


def run_model(num_prompts):
    print("Generating code solutions...")

    prompts = [sample["prompt"] for sample in combined_dataset]
    generated_solutions = []

    start_time = time.time()

    for prompt in prompts[:num_prompts]:
        solution = generate_code(prompt, model, tokenizer,"cuda")
        generated_solutions.append(solution)
        print(f"Prompt:\n{prompt}")
        print(f"Generated Solution:\n{solution}\n")

    current_time = time.time() - start_time
    num_solutions = len(generated_solutions)
    print(f"Completed processing. Generated solutions for {num_solutions} prompts in {current_time} seconds.")

num_prompts = 800
num_prompts = int(os.getenv("num_prompts", num_prompts))
run_model(num_prompts)

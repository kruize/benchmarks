import torch
import os
import re
import time
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset, concatenate_datasets

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}")

model_name = "Salesforce/codegen-350M-mono"

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

try: 
    tokenizer = AutoTokenizer.from_pretrained(model_name)   
    model = AutoModelForCausalLM.from_pretrained(model_name).to(device)
except Exception as e:
    print(f"Error loading model or tokenizer: {e}")

def generate_code(prompt, model, tokenizer, device, max_new_tokens=200):

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


def run_model_by_prompts(num_prompts):
    print("Generating code solutions...")

    prompts = [sample["prompt"] for sample in combined_dataset]
    generated_solutions = []

    start_time = time.time()

    for prompt in prompts[:num_prompts]:
        solution = generate_code(prompt, model, tokenizer, device)
        generated_solutions.append(solution)
        # print(f"Prompt:\n{prompt}")
        # print(f"Generated Solution:\n{solution}\n")

    current_time = time.time() - start_time
    num_solutions = len(generated_solutions)
    print(f"Completed processing. Generated solutions for {num_solutions} prompts in {current_time} seconds.")


def run_model_by_time(duration_in_seconds):
    print(f"Generating code solutions for {duration_in_seconds} seconds...")

    prompts = [sample["prompt"] for sample in combined_dataset]
    generated_solutions = []

    start_time = time.time()

    for prompt in prompts:
        if time.time() - start_time > duration_in_seconds:
            break
        solution = generate_code(prompt, model, tokenizer, "cuda")
        generated_solutions.append(solution)
        # print(f"Prompt:\n{prompt}")
        # print(f"Generated Solution:\n{solution}\n")

    elapsed_time = time.time() - start_time
    print(f"Completed processing. Generated solutions for {len(generated_solutions)} prompts in {elapsed_time:.2f} seconds.")


def main():
    """
    Main function to decide whether to run the model based on prompts or time. 
    if num_prompts is set in the job yaml it will pick that up
    if duration_in_seconds is set in job yaml it will pick that 
    if both of them are set num_prompts has a higher precedence.
    """
    num_prompts = os.getenv("num_prompts")
    duration_in_seconds = os.getenv("duration_in_seconds")

    if num_prompts is not None:
        run_model_by_prompts(int(num_prompts))
    elif duration_in_seconds is not None:
        run_model_by_time(int(duration_in_seconds))
    else:
        print("Neither 'num_prompts' nor 'duration_in_seconds' is set in the environment.")


if __name__ == "__main__":
    main()


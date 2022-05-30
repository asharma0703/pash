PASH_FLAGS='--width 8 --r_split --parallel_pipelines'
export TIMEFORMAT=%R

if [[ "$1" == "--small" ]]; then
    echo "Using small input"
    export ENTRIES=40
else
    echo "Using full input"
    export ENTRIES=1060
fi

names_scripts=(
    "1syllable_words;6_4"
    "2syllable_words;6_5"
    "4letter_words;6_2"
    "bigrams_appear_twice;8.2_2"
    "bigrams;4_3"
    "compare_exodus_genesis;8.3_3"
    "count_consonant_seq;7_2"
    # "count_morphs;7_1"
    "count_trigrams;4_3b"
    "count_vowel_seq;2_2"
    "count_words;1_1"
    "find_anagrams;8.3_2"
    "merge_upper;2_1"
    "sort;3_1"
    "sort_words_by_folding;3_2"
    "sort_words_by_num_of_syllables;8_1"
    "sort_words_by_rhyming;3_3"
    # "trigram_rec;6_1"
    "uppercase_by_token;6_1_1"
    "uppercase_by_type;6_1_2"
    "verses_2om_3om_2instances;6_7"
    "vowel_sequencies_gr_1K;8.2_1"
    "words_no_vowels;6_3"
  )

bash_nlp(){
  outputs_dir="outputs"
  rep=${1:-rep3}
  times_file=$rep"_seq.res"
  outputs_suffix=$rep"_seq.out"

  mkdir -p "$outputs_dir"

  touch "$times_file"
  echo executing Unix-for-nlp $(date) | tee -a "$times_file"
  echo '' >> "$times_file"

  for name_script in ${names_scripts[@]}
  do
    IFS=";" read -r -a name_script_parsed <<< "${name_script}"
    name="${name_script_parsed[0]}"
    script="${name_script_parsed[1]}"
    printf -v pad %30s
    padded_script="${name}.sh:${pad}"
    padded_script=${padded_script:0:30}

    outputs_file="${outputs_dir}/${script}.${outputs_suffix}"

    echo "${padded_script}" $({ time ./${script}.sh > "$outputs_file"; } 2>&1) | tee -a "$times_file"
  done
  cd ..
}

nlp_pash(){
  flags=${1:-$PASH_FLAGS}
  prefix=${2:-par}
  rep=${3:-rep3}
  prefix=$prefix\_$rep

  times_file="$prefix.res"
  outputs_suffix="$prefix.out"
  time_suffix="$prefix.time"
  outputs_dir="outputs"
  pash_logs_dir="pash_logs_$prefix"

  mkdir -p "$outputs_dir"
  mkdir -p "$pash_logs_dir"

  touch "$times_file"
  echo executing Unix-for-nlp with pash $(date) | tee -a "$times_file"
  echo '' >> "$times_file"

  for name_script in ${names_scripts[@]}
  do
    IFS=";" read -r -a name_script_parsed <<< "${name_script}"
    name="${name_script_parsed[0]}"
    script="${name_script_parsed[1]}"
    printf -v pad %30s
    padded_script="${name}.sh:${pad}"
    padded_script=${padded_script:0:30}

    outputs_file="${outputs_dir}/${script}.${outputs_suffix}"
    pash_log="${pash_logs_dir}/${script}.pash.log"
    single_time_file="${outputs_dir}/${script}.${time_suffix}"

    echo -n "${padded_script}" | tee -a "$times_file"
    { time "$PASH_TOP/pa.sh" $flags --log_file "${pash_log}" ${script}.sh > "$outputs_file"; } 2> "${single_time_file}"
    cat "${single_time_file}" | tee -a "$times_file"
  done
  cd ..
}

# bash_nlp "rep1"
bash_nlp "rep3"

# nlp_pash "$PASH_FLAGS" "par" "rep1"
nlp_pash "$PASH_FLAGS --parallel_pipelines_limit 8" "par" "rep3"

# nlp_pash "$PASH_FLAGS --distributed_exec" "distr" "rep1"
nlp_pash "$PASH_FLAGS --distributed_exec --parallel_pipelines_limit 24" "distr" "rep3"

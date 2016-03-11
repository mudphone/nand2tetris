(defmodule assembler
  (export (unwrap_label 1)
          (strip_comments 1)
          (strip_surrounding_whitespace 1)
          (assemble 2)))

(defun read_file_device (file)
  (case (file:open file '(read))
    ((tuple 'ok device)
     device)))

(defun int_to_padded_binary (d_num)
  (++ "0"
      (lists:flatten
       (io_lib:format "~15.2.0B" (list d_num)))))

(defun strip_surrounding_whitespace (line)
  (binary:bin_to_list
   (binary:list_to_bin
    (re:replace (string:strip line) "\\s+$" "" (list 'global)))))

(defun registers ()
  (map
   "SP"     (int_to_padded_binary 0)
   "LCL"    (int_to_padded_binary 1)
   "ARG"    (int_to_padded_binary 2)
   "THIS"   (int_to_padded_binary 3) 
   "THAT"   (int_to_padded_binary 4)
   "R0"     (int_to_padded_binary 0)
   "R1"     (int_to_padded_binary 1)
   "R2"     (int_to_padded_binary 2)
   "R3"     (int_to_padded_binary 3)
   "R4"     (int_to_padded_binary 4)
   "R5"     (int_to_padded_binary 5)
   "R6"     (int_to_padded_binary 6)
   "R7"     (int_to_padded_binary 7)
   "R8"     (int_to_padded_binary 8)
   "R9"     (int_to_padded_binary 9)
   "R10"    (int_to_padded_binary 10)
   "R11"    (int_to_padded_binary 11)
   "R12"    (int_to_padded_binary 12)
   "R13"    (int_to_padded_binary 13)
   "R14"    (int_to_padded_binary 14)
   "R15"    (int_to_padded_binary 15)
   "SCREEN" (int_to_padded_binary 16384)
   "KBD"    (int_to_padded_binary 24576)))

(defun lookup_register (r)
  (mref (registers) r))

(defun is_string_all_digits (str)
  (== 0 (length (binary:bin_to_list (binary:list_to_bin (re:split str "[0123456789]"))))))

(defun process_a_command (a_cmd symbol_table next_ram_address)
  (let ((suffix (lists:sublist a_cmd 2 (- (string:len a_cmd) 1))))
    (io:format "lookup a cmd key (suffix): ~p~n" (list suffix))
    (cond
     ((maps:is_key suffix (registers))
      (tuple 'a_cmd (lookup_register suffix) symbol_table next_ram_address))
     ((maps:is_key suffix symbol_table)
      (tuple 'a_cmd (mref symbol_table suffix) symbol_table next_ram_address))
     ((not (is_string_all_digits suffix))
      (process_a_command a_cmd
                         (mset symbol_table suffix (int_to_padded_binary next_ram_address))
                         (+ 1 next_ram_address)))
     ((?= (tuple i _) (string:to_integer suffix))
      (tuple 'a_cmd (int_to_padded_binary i) symbol_table next_ram_address)))))

(defun comp_fields ()
  (map
   "0"   "0101010"
   "1"   "0111111"
   "-1"  "0111010"
   "D"   "0001100"
   "A"   "0110000"
   "!D"  "0001101"
   "!A"  "0110001"
   "-D"  "0001111"
   "-A"  "0110011"
   "D+1" "0011111"
   "A+1" "0110111"
   "D-1" "0001110"
   "A-1" "0110010"
   "D+A" "0000010"
   "D-A" "0010011"
   "A-D" "0000111"
   "D&A" "0000000"
   "D|A" "0010101"
   "M"   "1110000"
   "!M"  "1110001"
   "-M"  "1110011"
   "M+1" "1110111"
   "M-1" "1110010"
   "D+M" "1000010"
   "D-M" "1010011"
   "M-D" "1000111"
   "D&M" "1000000"
   "D|M" "1010101"))

(defun lookup_comp (comp)
  (mref (comp_fields) comp))

(defun dest_fields ()
  (map
   "M"   "001"
   "D"   "010"
   "MD"  "011"
   "A"   "100"
   "AM"  "101"
   "AD"  "110"
   "AMD" "111"))

(defun lookup_dest (dest)
  (mref (dest_fields) dest))

(defun jump_fields ()
  (map
   "JGT" "001"
   "JEQ" "010"
   "JGE" "011"
   "JLT" "100"
   "JNE" "101"
   "JLE" "110"
   "JMP" "111"))

(defun lookup_jump (jump)
  (mref (jump_fields) jump))

(defun translate_dest_comp (dest comp)
  (let ((prefix "111")
        (c (lookup_comp comp))
        (d (lookup_dest dest))
        (j "000"))
    (++ prefix c d j)))

(defun translate_comp_jump (comp jump)
  (let ((prefix "111")
        (c (lookup_comp comp))
        (d "000")
        (j (lookup_jump jump)))
    (++ prefix c d j)))

(defun process_c_command (c_cmd)
  (let ((parts (string:tokens c_cmd "=;"))
        (contains_eq (< 0 (string:rstr c_cmd "=")))
        (contains_semicolon (< 0 (string:rstr c_cmd ";"))))
    (cond
     ((?= (list dest comp) (when contains_eq) parts)
      (translate_dest_comp dest comp))
     ((?= (list comp jump) (when contains_semicolon) parts)
      (translate_comp_jump comp jump)))))

(defun categorize_line
  (('eof) 'eof)
  
  ;; blank lines / newlines only
  ((line) (when (== 0 (length line)))
   'skip)

  ;; newline characters
  ;; 10 is unicode for "\n"
  ;; skip lines with only a newline character
  (((cons f r)) (when (and (== 10 f)
                           (== 0 (length r))))
   'skip)
  
  ;; comment lines
  ;; 47 is unicode for "/"
  ;; I'm checking for comment lines starting with "//"
  (((cons f r)) (when (and (== 47 f)
                           (== 47 (hd r))))
   'skip)

  ;; A (@) commands
  ;; 64 is unicode for "@"
  ;; I'm checking for "AT commands"
  ((line) (when (== 64 (hd line)))
   (tuple 'a_cmd line))

  ;; Labels
  ;; 40 is a "(" which is used by labels
  ((line) (when (== 40 (hd line)))
   (tuple 'label line))
  
  ;; C commands
  ((line)
   (tuple 'c_cmd line)))

(defun process_line (line symbol_table next_ram_address)
  (let ((meta_line (categorize_line line)))
    (io:format "meta_line: ~p~n" (list meta_line))
    (case meta_line
      ('eof 'eof)
      ('skip 'skip)
      ((tuple 'a_cmd ln)
       (process_a_command ln symbol_table next_ram_address))
      ((tuple 'label _)
       'skip)
      ((tuple 'c_cmd ln)
       (process_c_command ln)))))

(defun strip_comments (line)
  (let (((cons head tail) (re:split line "//")))
    (cond
     ((< 0 (length tail))
      (binary:bin_to_list head))
     ('true line))))

(defun prepare_line (file_device)
  (case (io:get_line file_device "")
    ('eof 'eof)
    (line (let ((stripped (strip_surrounding_whitespace
                           (strip_comments line))))
            (io:format "line: ~p~n" (list stripped))
            stripped))))

(defun chop_last_char (line)
  (string:sub_string line 1 (- (string:len line) 1)))

(defun write_line (file line)
  (file:write_file file
                   (io_lib:fwrite "~s~n" (list line))
                   (list 'append)))

(defun read_all_lines (read_device write_file_name symbol_table next_ram_address)
  (let ((processed (process_line (prepare_line read_device)
                                 symbol_table
                                 next_ram_address)))
    (io:format "processed: ~p~n" (list processed))
    (case processed 
      ('eof 'done)
      ('skip (read_all_lines read_device write_file_name symbol_table next_ram_address))
      ((tuple 'a_cmd line sym_tbl nxt_ram_adr)
       (begin
         (write_line write_file_name line)
         (read_all_lines read_device write_file_name sym_tbl nxt_ram_adr)))
      (line
       (begin
         (write_line write_file_name line)
         (read_all_lines read_device write_file_name symbol_table next_ram_address))))))

(defun unwrap_label (line)
  (lists:sublist line 2 (- (string:len line) 2)))

(defun parse_label (line rom_address symbol_table)
  (io:format "2 symbol table: ~p~n" (list symbol_table))
  (mset symbol_table (unwrap_label line)
        (int_to_padded_binary rom_address)))

(defun symbol_pass (read_device)
   (symbol_pass read_device 0 (map)))

(defun symbol_pass (read_device rom_address symbol_table)
  (case (categorize_line (prepare_line read_device))
    ('eof symbol_table)
    ('skip            (symbol_pass read_device rom_address symbol_table))
    ((tuple 'a_cmd _) (symbol_pass read_device (+ 1 rom_address) symbol_table))
    ((tuple 'c_cmd _) (symbol_pass read_device (+ 1 rom_address) symbol_table))
    ((tuple 'label line) (symbol_pass read_device rom_address (parse_label line rom_address symbol_table)))))

(defun assemble (read_file_name write_file_name)
  (let ((first_file_dev (read_file_device read_file_name)))
    (let ((symbol_table (try
                          (symbol_pass first_file_dev)
                          (after
                              (file:close first_file_dev))))
        (read_dev (read_file_device read_file_name)))
    (io:format "symbol table: ~p~n" (list symbol_table))
    (read_all_lines read_dev write_file_name symbol_table 16)))
  )
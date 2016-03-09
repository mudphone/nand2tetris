(defmodule assembler
  (export (unwrap_label 1)
          (strip_comments 1)
          (assemble 2)))

(defun read_file_device (file)
  (case (file:open file '(read))
    ((tuple 'ok device)
     device)))

(defun flatten_decimal_num (d_num)
  (++ "0"
      (lists:flatten
       (io_lib:format "~15.2.0B" (list d_num)))))

(defun is_symbol (symbol_or_dec)
  'false)

(defun strip_surrounding_whitespace (line)
  (binary:bin_to_list
   (binary:list_to_bin
    (re:replace (string:strip line) "\\s+$" "" (list 'global)))))

(defun process_a_command (a_cmd)
  (let ((suffix (lists:sublist a_cmd 2 (- (string:len a_cmd) 1))))
    (if (is_symbol suffix)
      "not processing symbols yet"
      (let (((tuple i _) (string:to_integer suffix)))
        (flatten_decimal_num i)))))

(defun lookup_comp (comp)
  (mref (map
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
         "D|M" "1010101") comp))

(defun lookup_dest (dest)
  (mref (map
         "M"   "001"
         "D"   "010"
         "MD"  "011"
         "A"   "100"
         "AM"  "101"
         "AD"  "110"
         "AMD" "111") dest))

(defun lookup_jump (jump)
  (mref (map
         "JGT" "001"
         "JEQ" "010"
         "JGE" "011"
         "JLT" "100"
         "JNE" "101"
         "JLE" "110"
         "JMP" "111") jump))

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

(defun process_line
  ;; blank lines / newlines only
  ((line) (when (== 0 (length line)))
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
   (tuple 'a_cmd (process_a_command line)))

  ;; Labels
  ;; 40 is a "(" which is used by labels
  ((line) (when (== 40 (hd line)))
   (tuple 'label line))
  
  ;; C commands
  ((line)
   (tuple 'c_cmd (process_c_command line))))

(defun strip_comments (line)
  (let (((cons head tail) (re:split line "//")))
    (cond
     ((< 0 (length tail))
      (binary:bin_to_list head))
     ('true line))))

(defun read_line (file_device)
  (case (io:get_line file_device "")
    ('eof 'eof)
    (line (let ((stripped (strip_surrounding_whitespace
                           (strip_comments line))))
            (io:format "line: ~p~n" (list stripped))
            (process_line stripped)))))

(defun chop_last_char (line)
  (string:sub_string line 1 (- (string:len line) 1)))

(defun write_line (file line)
  (file:write_file file
                   (io_lib:fwrite "~s~n" (list line))
                   (list 'append)))

(defun read_all_lines (read_device write_file_name)
  (case (read_line read_device)
    ('eof "")
    ('skip (read_all_lines read_device write_file_name))
    ((tuple _ line)
     (begin
       (write_line write_file_name line)
       (read_all_lines read_device write_file_name)))))

(defun unwrap_label (line)
  (lists:sublist line 2 (- (string:len line) 2)))

(defun parse_cmd_or_label
  ((line_type _ rom_address symbol_table) (when (or (== line_type 'a_cmd)
                                                    (== line_type 'c_cmd)))
   (list (+ 1 rom_address) symbol_table))
  (('label line rom_address symbol_table)
   (let ((lab (unwrap_label line)))
     (list rom_address (mset symbol_table lab (+ 1 rom_address))))))

(defun symbol_pass (read_device)
   (symbol_pass read_device 0 (map)))

(defun symbol_pass (read_device rom_address symbol_table)
   (case (read_line read_device)
     ('eof symbol_table)
     ('skip (symbol_pass read_device rom_address symbol_table))
     ((tuple line_type line)
      (let (((list rom sym) (parse_cmd_or_label line_type line rom_address symbol_table)))
        (symbol_pass read_device rom sym)))))

(defun assemble (read_file_name write_file_name)
  (let ((symbol_table (symbol_pass (read_file_device read_file_name)))
        (read_dev (read_file_device read_file_name)))
    (io:format "~p~n" (list symbol_table))
    (read_all_lines read_dev write_file_name)))
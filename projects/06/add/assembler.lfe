(defmodule assembler
  (export (file_device 1)
          (read_line 1)
          (process_line 1)
          (process_a_command 1)
          (flatten_decimal_num 1)
          (read_all_lines 1)))

(defun file_device (file)
  (case (file:open file '(read))
    ((tuple 'ok device)
     device)))

(defun flatten_decimal_num (d_num)
  (++ "0"
      (lists:flatten
       (io_lib:format "~15.2.0B" (list d_num)))))

(defun is_symbol (symbol_or_dec)
  'false)

(defun strip_trailing_whitespace (line)
  (binary:bin_to_list
   (binary:list_to_bin
    (re:replace line "\\s+$" "" (list 'global)))))

(defun process_a_command (a_cmd)
  (let ((suffix (lists:sublist a_cmd 2 (- (string:len a_cmd) 1))))
    (if (is_symbol suffix)
      "not processing symbols yet"
      (let (((tuple i _) (string:to_integer suffix)))
        (flatten_decimal_num i)))))

(defun lookup-comp (comp)
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

(defun lookup-dest (dest)
  (mref (map
         "M"   "001"
         "D"   "010"
         "MD"  "011"
         "A"   "100"
         "AM"  "101"
         "AD"  "110"
         "AMD" "111") dest))

(defun translate_dest_comp (dest comp)
  (let ((prefix "111")
        (j "000")
        (c (lookup-comp comp))
        (d (lookup-dest dest)))
    (++ j c d)))

(defun process_c_command (c_cmd)
  (let ((parts (string:tokens c_cmd "=;"))
        (contains_eq (< 0 (string:rstr c_cmd "=")))
        (contains_semicolon (< 0 (string:rstr c_cmd ";"))))
    (cond
     ((?= (list dest comp jump) parts)
      "three parts")
     ((?= (list dest comp) (when contains_eq) parts)
      (translate_dest_comp dest comp))
     ((?= (list comp jump) (when contains_semicolon) parts)
      "two parts with ;")
     ('true "bad c command parsing"))))

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
   (process_a_command line))

  ;; Labels
  ;; 40 is a "(" which is used by labels
  ((line) (when (== 40 (hd line)))
   line)
  
  ;; C commands
  ((line) (process_c_command line)))

(defun read_line (file_device)
  (case (io:get_line file_device "")
    ('eof 'eof)
    (line (process_line
           (strip_trailing_whitespace line)))))

(defun chop_last_char (line)
  (string:sub_string line 1 (- (string:len line) 1)))

(defun read_all_lines (file_device)
  (case (read_line file_device)
    ('eof "")
    ('skip (read_all_lines file_device))
    (line (++ line "~n" (read_all_lines file_device)))))

;; (defun assemble [file]
;;   (file_device file))
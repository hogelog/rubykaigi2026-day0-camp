# frozen_string_literal: true

# 01 の「wrong type of arguments」が puts(Integer) 由来かを切り分ける最小再現。
# typeprof 0.31.1 の組み込み RBS では Kernel#puts(*String) になっている疑い。

def id_int(x) = x
def id_str(x) = x

id_int(1)
id_str("a")
puts id_int(1) # Integer を puts
puts id_str("a") # String を puts
p id_int(1) # Integer を p

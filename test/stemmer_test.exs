defmodule StemmerTest do
  use ExUnit.Case

  test "the truth" do
    assert(true)

    file = File.open!("./test/test_data.txt", [:read])

    process_file(file)
  end

  def process_file(file) do
    row = IO.read(file, :line)

    if (row != :eof) do
      [word1, word2] = handle_row(row)

      assert(Stemmer.stem(word1) == word2)

      process_file(file)
    end
  end

  def handle_row(row) do
    list = Regex.split(~r{ }, row)
    Enum.filter_map(list, fn(e) -> e != "" end, fn(e) -> String.replace(e, "\n", "") end)
  end
end

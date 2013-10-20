defmodule Stemmer do
  def stem(input_word) do
    word = to_string(input_word)

    if size(word) <= 2 do
      word
    else
      normalized_word = word |> normalize # |> stem_exception

      case stem_exception(normalized_word) do
        nil ->
          [r1, r2] = get_regions(normalized_word)

          normalized_word |> step_0
                          |> step_1a
                          |> step_1b(r1, r2)
                          |> step_1c
                          |> step_2(r1)
                          |> step_3(r1, r2)
                          |> step_4(r2)
                          |> step_5a(r1, r2)

        x -> x
      end
    end
  end

  defp step_0(word) do
    [head|_] = Regex.split(%r/('s'|'s|')$/, word)
    head
  end

  defp step_1a(word) do
    cond do
      word =~ %r/sses$/ ->
        String.replace(word, %r/sses$/, "ss")
      word =~ %r/ie[sd]$/ ->
        [head|tail] = Regex.split(%r/ie[sd]$/, word)
        subst = if size(head) > 1, do: "i", else: "ie"
        String.replace(word, %r/ie[sd]$/, subst)
      word =~ %r/#{vowels}.+s$/ and !(word =~ %r/(us|ss)$/) ->
        String.replace(word, %r/s$/, "")
      true -> word
    end
  end

  defp step_1b(word, region1, region2) do
    case is_exceptional?(word) do
      true -> word
      false ->
        cond do
          word =~ %r/(eed|eedly)$/ ->
            [{len,_}|_] = Regex.run(%r/(eed|eedly)$/, word, return: :index)
            [stem,_,_] = Regex.split(%r/(eed|eedly)$/, word)
            if region1 <= len do
              stem <> "ee"
            else
              word
            end

          word =~ %r/#{vowels}.*(ingly|edly|ing|ed)$/ ->
            suffix = List.last(Regex.run(%r/#{vowels}.*(ingly|edly|ing|ed)$/, word))
            stem = String.replace(word, %r/#{suffix}$/, "")
            cond do
              stem =~ %r/(at|bl|iz)$/ ->
                stem <> "e"
              stem =~ %r/(bb|dd|ff|gg|mm|nn|pp|rr|tt)$/ ->
                chop(stem)
              is_short?(stem, region1) ->
                stem <> "e"
              true -> stem
            end

          true -> word
        end
    end
  end

  defp step_1c(word) do
    case is_exceptional?(word) do
      true -> word
      false -> if word =~ %r/.+#{consonants}[yY]$/, do: String.replace(word, %r/[yY]$/, "i"), else: word
    end
  end

  defp step_2(word, region1) do
    case is_exceptional?(word) do
      true -> word
      false ->
        cond do
          word =~ %r/(ational|fulness|iveness|ization|ousness|biliti|lessli|tional|ation|alism|aliti|entli|fulli|iviti|ousli|enci|anci|abli|izer|ator|alli|bli)$/ ->
            [stem,suffix, ""] = Regex.split(%r/(ational|fulness|iveness|ization|ousness|biliti|lessli|tional|ation|alism|aliti|entli|fulli|iviti|ousli|enci|anci|abli|izer|ator|alli|bli)$/, word)
            if region1 <= size(stem) do
              stem <> normalize_suffix_1(suffix)
            else
              word
            end

          word =~ %r/ogi$/ ->
            [stem,_] = Regex.split(%r/ogi$/, word)
            if region1 <= size(stem) and stem =~ %r/l$/, do: String.replace(word, %r/ogi$/, 'og'), else: word

          word =~ %r/(.*[cdeghkmnrt])li$/ ->
            [_,stem] = Regex.run(%r/(.*[cdeghkmnrt])li$/, word)
            if region1 <= size(stem), do: String.replace(word, %r/li$/, ""), else: word

          true ->
            word
        end
    end
  end

  defp step_3(word, region1, region2) do
    case is_exceptional?(word) do
      true -> word
      false ->
        cond do
          word =~ %r/(ational|tional|alize|icate|iciti|ical|ness|ful)$/ ->
            [stem,suffix, ""] = Regex.split(%r/(ational|tional|alize|icate|iciti|ical|ness|ful)$/, word)
            if region1 <= size(stem), do: stem <> normalize_suffix_2(suffix), else: word

          word =~ %r/ative$/ ->
            [stem, _] = Regex.split(%r/ative$/, word)
            if region2 <= size(stem), do: stem, else: word

          true ->
            word
        end
    end
  end

  defp step_4(word, region2) do
    if is_exceptional?(word), do: word

    suffix1 = %r/(ement|able|ance|ence|ible|ment|ant|ate|ent|ism|iti|ive|ize|ous|al|er|ic|ou)$/
    suffix2 = %r/(.*[st])ion$/

    parts = cond do
      word =~ suffix1 -> Regex.split(suffix1, word)
      word =~ suffix2 -> Regex.split(suffix2, word)
      true -> nil
    end

    case parts do
      ["", stem, ""] -> if region2 <= size(stem), do: stem, else: word
      [stem, suffix, ""] -> if region2 <= size(stem), do: stem, else: word
      nil -> word
    end
  end

  defp step_5a(word, region1, region2) do
    if is_exceptional?(word), do: word

    suffix1 = %r/e$/
    suffix2 = %r/(.*l)l$/

    penultimate = cond do
      word =~ suffix1 ->
        case Regex.split(suffix1, word) do
          [stem, ""]     -> if region2 <= size(stem) or (region1 <= size(stem) and !is_short?(stem, region1)), do: chop(word), else: word
          ["", stem, ""] -> if region2 <= size(stem) or (region1 <= size(stem) and !is_short?(stem, region1)), do: chop(word), else: word
          nil -> word
        end

      word =~ suffix2 ->
        case Regex.run(suffix2, word) do
          [_,stem] ->
            if region2 <= size(stem), do: chop(word), else: word

          nil -> word
        end

      true ->
        word
    end

    String.replace(penultimate, "Y", "y")
  end

  defp chop(str) do
    String.slice(str, 0, size(str) - 1)
  end

  defp vowels do
    "[aeiouy]"
  end

  defp consonants do
    "[^aeiou]"
  end

  defp is_exceptional?(word) do
    # Should be checked at each step except steps 0 and 1a
    Enum.member?(%w(inning outing canning herring earring proceed exceed succeed), word)
  end

  defp is_short?(word, region1) do
    region1 >= size(word) && ends_with_short_syllable?(word)
  end

  defp ends_with_short_syllable?(word) do
    word =~ %r/((^#{vowels}#{consonants})|(#{consonants}#{vowels}[^aeiouywxY]))$/
  end

  defp get_regions(word) do
    region1 = case Regex.run(%r/^(gener|commun|arsen)/, word, return: :index) do
      [{_, len}|_] -> len
      nil ->
        case Regex.run(%r/#{vowels}#{consonants}/, word, return: :index) do
          [{pos, _}|_] -> pos + 2
          nil          -> size(word)
        end
    end

    region2 = case Regex.run(%r/.{#{region1}}#{vowels}#{consonants}/, word, return: :index) do
      [{pos,_}|_] -> pos + region1 + 2
      nil -> size(word)
    end

    [region1, region2]
  end

  defp stem_exception(word) do
    case word do
      "skis"   -> "ski"
      "skies"  -> "sky"
      "dying"  -> "die"
      "lying"  -> "lie"
      "tying"  -> "tie"
      "idly"   -> "idl"
      "gently" -> "gentl"
      "ugly"   -> "ugli"
      "early"  -> "earli"
      "only"   -> "onli"
      "singly" -> "singl"
      "sky"    -> "sky"
      "news"   -> "news"
      "howe"   -> "howe"
      "atlas"  -> "atlas"
      "cosmos" -> "cosmos"
      "bias"   -> "bias"
      "andes"  -> "andes"
      _        -> nil
    end
  end

  defp normalize_suffix_1(suffix) do
    case suffix do
      "tional"  -> "tion"
      "enci"    -> "ence"
      "anci"    -> "ance"
      "abli"    -> "able"
      "entli"   -> "ent"
      "izer"    -> "ize"
      "ization" -> "ize"
      "ational" -> "ate"
      "ation"   -> "ate"
      "ator"    -> "ate"
      "alism"   -> "al"
      "aliti"   -> "al"
      "alli"    -> "al"
      "fulness" -> "ful"
      "ousli"   -> "ous"
      "ousness" -> "ous"
      "iveness" -> "ive"
      "iviti"   -> "ive"
      "biliti"  -> "ble"
      "bli"     -> "ble"
      "ogi"     -> "og"
      "fulli"   -> "ful"
      "lessli"  -> "less"
      _         -> ""
    end
  end

  defp normalize_suffix_2(suffix) do
    case suffix do
      "tional"  -> "tion"
      "ational" -> "ate"
      "alize"   -> "al"
      "icate"   -> "ic"
      "iciti"   -> "ic"
      "ical"    -> "ic"
      _         -> ""
    end
  end

  defp normalize(word) do
    word |> String.replace(%r/^'/, '')
         |> String.replace(%r/^y/, 'Y')
  end
end
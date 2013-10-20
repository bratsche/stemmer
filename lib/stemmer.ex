defmodule Stemmer do
  @moduledoc """
  Porter 2 stemmer algorithm.
  """

  @doc """
  Provides the stemmed version of the input word.
  """
  def stem(input_word) do
    word = to_string(input_word) |> String.strip |> String.downcase
    stem word, stem_exception(word)
  end

  defp stem(_, exceptional_stem) when exceptional_stem != nil, do: exceptional_stem
  defp stem(word, nil) when size(word) <= 2, do: word
  defp stem(word, nil) do
    word = word |> String.replace(%r/^'/, "") |> String.replace(%r/^y/, "Y")

    [r1, r2] = get_regions(word)

    word
      |> step_0
      |> step_1a
      |> step_1b(r1)
      |> step_1c
      |> step_2(r1)
      |> step_3(r1, r2)
      |> step_4(r2)
      |> step_5(r1, r2)
  end

  ### algorithm steps

  defp step_0(word) do
    Regex.split(%r/('s'|'s|')$/, word) |> Enum.first
  end

  defp step_1a(word) do
    sses_suffix_rule = %r/sses$/
    ie_suffix_rule = %r/ie[sd]$/

    cond do
      word =~ sses_suffix_rule ->
        String.replace(word, sses_suffix_rule, "ss")
      word =~ ie_suffix_rule ->
        [head | _] = Regex.split(ie_suffix_rule, word)
        subst = if size(head) > 1, do: "i", else: "ie"
        String.replace(word, ie_suffix_rule, subst)
      word =~ %r/#{vowels}.+s$/ and !(word =~ %r/(us|ss)$/) ->
        String.replace(word, %r/s$/, "")
      true -> word
    end
  end

  defp step_1b(word, region1), do: step_1b(word, region1, exceptional?(word))
  defp step_1b(word, _, exceptional) when exceptional, do: word
  defp step_1b(word, region1, _) do
    eed_suffix_rule = %r/(eed|eedly)$/
    ing_or_ed_suffix_rule = %r/#{vowels}.*(ingly|edly|ing|ed)$/

    cond do
      word =~ eed_suffix_rule ->
        [{len, _} | _] = Regex.run(eed_suffix_rule, word, return: :index)
        [stem, _, _] = Regex.split(eed_suffix_rule, word)
        if region1 <= len, do: stem <> "ee", else: word

      word =~ ing_or_ed_suffix_rule ->
        suffix = List.last(Regex.run(ing_or_ed_suffix_rule, word))
        stem = String.replace(word, %r/#{suffix}$/, "")
        cond do
          stem =~ %r/(bb|dd|ff|gg|mm|nn|pp|rr|tt)$/ ->
            chop(stem)
          stem =~ %r/(at|bl|iz)$/ or is_short?(stem, region1) ->
            stem <> "e"
          true -> stem
        end

      true -> word
    end
  end

  defp step_1c(word), do: step_1c(word, exceptional?(word))
  defp step_1c(word, exceptional) when exceptional, do: word
  defp step_1c(word, _) do
    if word =~ %r/.+#{consonants}[yY]$/, do: String.replace(word, %r/[yY]$/, "i"), else: word
  end

  defp step_2(word, region1), do: step_2(word, region1, exceptional?(word))
  defp step_2(word, _, exceptional) when exceptional, do: word
  defp step_2(word, region1, _) do
    multiple_suffix_rule = %r/(ational|fulness|iveness|ization|ousness|biliti|lessli|tional|ation|alism|aliti|entli|fulli|iviti|ousli|enci|anci|abli|izer|ator|alli|bli)$/
    ogi_suffix_rule = %r/ogi$/
    li_suffix_rule = %r/(.*[cdeghkmnrt])li$/

    cond do
      word =~ multiple_suffix_rule ->
        [stem, suffix, ""] = Regex.split(multiple_suffix_rule, word)
        if region1 <= size(stem), do: stem <> normalize_suffix_1(suffix), else: word

      word =~ ogi_suffix_rule ->
        [stem, _] = Regex.split(ogi_suffix_rule, word)
        if region1 <= size(stem) and stem =~ %r/l$/, do: String.replace(word, ogi_suffix_rule, "og"), else: word

      word =~ li_suffix_rule ->
        [_, stem] = Regex.run(li_suffix_rule, word)
        if region1 <= size(stem), do: String.replace(word, %r/li$/, ""), else: word

      true ->
        word
    end
  end

  defp step_3(word, region1, region2), do: step_3(word, region1, region2, exceptional?(word))
  defp step_3(word, _, _, exceptional) when exceptional, do: word
  defp step_3(word, region1, region2, _) do
    al_ic_ness_ful_suffix_rule = %r/(ational|tional|alize|icate|iciti|ical|ness|ful)$/
    ative_suffix_rule = %r/ative$/

    cond do
      word =~ al_ic_ness_ful_suffix_rule ->
        [stem,suffix, ""] = Regex.split(al_ic_ness_ful_suffix_rule, word)
        if region1 <= size(stem), do: stem <> normalize_suffix_2(suffix), else: word

      word =~ ative_suffix_rule ->
        [stem, _] = Regex.split(ative_suffix_rule, word)
        if region2 <= size(stem), do: stem, else: word

      true ->
        word
    end
  end

  defp step_4(word, region2), do: step_4(word, region2, exceptional?(word))
  defp step_4(word, _, exceptional) when exceptional, do: word
  defp step_4(word, region2, _) do
    suffix_list_rule = %r/(ement|able|ance|ence|ible|ment|ant|ate|ent|ism|iti|ive|ize|ous|al|er|ic|ou)$/
    ion_suffix_rule = %r/(.*[st])ion$/

    parts = cond do
      word =~ suffix_list_rule -> Regex.split(suffix_list_rule, word)
      word =~ ion_suffix_rule  -> Regex.split(ion_suffix_rule, word)
      true -> nil
    end

    case parts do
      ["", stem, ""] -> if region2 <= size(stem), do: stem, else: word
      [stem, _, ""]  -> if region2 <= size(stem), do: stem, else: word
      nil -> word
    end
  end

  defp step_5(word, region1, region2), do: step_5(word, region1, region2, exceptional?(word))
  defp step_5(word, _, _, exceptional) when exceptional, do: word
  defp step_5(word, region1, region2, _) do
    e_suffix_rule = %r/e$/
    l_suffix_rule = %r/(.*l)l$/

    penultimate = cond do
      word =~ e_suffix_rule ->
        handle_e_rule = fn(word, stem) ->
          if region2 <= size(stem) or (region1 <= size(stem) and !is_short?(stem, region1)), do: chop(word), else: word
        end
        case Regex.split(e_suffix_rule, word) do
          [stem, ""]     -> handle_e_rule.(word, stem)
          ["", stem, ""] -> handle_e_rule.(word, stem)
          nil            -> word
        end

      word =~ l_suffix_rule ->
        case Regex.run(l_suffix_rule, word) do
          [_, stem] -> if region2 <= size(stem), do: chop(word), else: word
          nil       -> word
        end

      true ->
        word
    end

    String.replace(penultimate, "Y", "y")
  end

  ### utilities

  defp chop(str) do
    String.slice(str, 0, size(str) - 1)
  end

  defp exceptional?(word) do
    # Should be checked at each step except steps 0 and 1a
    Enum.member?(%w(inning outing canning herring earring proceed exceed succeed), word)
  end

  defp is_short?(word, region1) do
    region1 >= size(word) && word =~ %r/((^#{vowels}#{consonants})|(#{consonants}#{vowels}[^aeiouywxY]))$/
  end

  defp get_regions(word) do
    region1 = case Regex.run(%r/^(gener|commun|arsen)/, word, return: :index) do
      [{_, len} | _] -> len
      nil ->
        case Regex.run(%r/#{vowels}#{consonants}/, word, return: :index) do
          [{pos, _} | _] -> pos + 2
          nil            -> size(word)
        end
    end

    region2 = case Regex.run(%r/.{#{region1}}#{vowels}#{consonants}/, word, return: :index) do
      [{pos, _} | _] -> pos + region1 + 2
      nil            -> size(word)
    end

    [region1, region2]
  end

  ### lookups

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

  defp vowels do
    "[aeiouy]"
  end

  defp consonants do
    "[^aeiou]"
  end
end

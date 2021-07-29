defmodule Stemmer do
  defmodule Context do
    defstruct region1: nil, region2: nil, str: nil, halted: false
  end

  def stem(input_word) do
    word = to_string(input_word)

    if String.length(word) <= 2 do
      word
    else
      context = word |> normalize |> stem_exception

      case context.halted do
        false ->
          context |> step_0
                  |> step_1a
                  |> step_1b
                  |> step_1c
                  |> step_2
                  |> step_3
                  |> step_4
                  |> step_5a

        true -> context.str
      end
    end
  end

  defp step_0(context) do
    [head|_] = Regex.split(~r{('s'|'s|')$}, context.str)
    %Context{context | str: head}
  end

  defp step_1a(context) do
    tmp = cond do
      context.str =~ ~r{sses$} ->
        %Context{context | str: String.replace(context.str, ~r{sses$}, "ss")}
      context.str =~ ~r{ie[sd]$} ->
        [head|_] = Regex.split(~r{ie[sd]$}, context.str)
        subst = if String.length(head) > 1, do: "i", else: "ie"
        %Context{context | str: String.replace(context.str, ~r{ie[sd]$}, subst)}
      context.str =~ ~r{#{vowels()}.+s$} and !(context.str =~ ~r{(us|ss)$}) ->
        %Context{context | str: String.replace(context.str, ~r{s$}, "")}
      true -> context
    end

    %Context{tmp | halted: Enum.member?(~w(inning outing canning herring earring proceed exceed succeed), tmp.str)}
  end

  defp step_1b(context = %{halted: true}), do: context
  defp step_1b(context) do
    cond do
      context.str =~ ~r{(eed|eedly)$} ->
        [{len,_}|_] = Regex.run(~r{(eed|eedly)$}, context.str, return: :index)
        [stem,_] = Regex.split(~r{(eed|eedly)$}, context.str, include_capture: true)
        if context.region1 <= len do
          %Context{context | str: stem <> "ee"}
        else
          %Context{context | str: context.str}
        end

      context.str =~ ~r{#{vowels()}.*(ingly|edly|ing|ed)$} ->
        suffix = List.last(Regex.run(~r{#{vowels()}.*(ingly|edly|ing|ed)$}, context.str))
        stem = String.replace(context.str, ~r{#{suffix}$}, "")
        cond do
          stem =~ ~r{(at|bl|iz)$} ->
            %Context{context | str: stem <> "e"}
          stem =~ ~r{(bb|dd|ff|gg|mm|nn|pp|rr|tt)$} ->
            %Context{context | str: chop(stem)}
          is_short?(stem, context.region1) ->
            %Context{context | str: stem <> "e"}
          true -> %Context{context | str: stem}
        end

      true -> context
    end
  end

  defp step_1c(context = %{halted: true}), do: context
  defp step_1c(context) do
    if context.str =~ ~r{.+#{consonants()}[yY]$} do
      %Context{context | str: String.replace(context.str, ~r{[yY]$}, "i")}
    else
      context
    end
  end

  defp step_2(context = %{halted: true}), do: context
  defp step_2(context) do
    cond do
      context.str =~ ~r{(ational|fulness|iveness|ization|ousness|biliti|lessli|tional|ation|alism|aliti|entli|fulli|iviti|ousli|enci|anci|abli|izer|ator|alli|bli)$} ->
        [stem,suffix, ""] = Regex.split(~r{(ational|fulness|iveness|ization|ousness|biliti|lessli|tional|ation|alism|aliti|entli|fulli|iviti|ousli|enci|anci|abli|izer|ator|alli|bli)$}, context.str, include_captures: true)
        if context.region1 <= String.length(stem) do
          %Context{context | str: stem <> normalize_suffix_1(suffix)}
        else
          context
        end

      context.str =~ ~r{ogi$} ->
        [stem,_] = Regex.split(~r{ogi$}, context.str)
        if context.region1 <= String.length(stem) and stem =~ ~r{l$} do
          %Context{context | str: String.replace(context.str, ~r{ogi$}, "og")}
        else
          context
        end

      context.str =~ ~r{(.*[cdeghkmnrt])li$} ->
        [_,stem] = Regex.run(~r{(.*[cdeghkmnrt])li$}, context.str)
        if context.region1 <= String.length(stem) do
          %Context{context | str: String.replace(context.str, ~r{li$}, "")}
        else
          context
        end

      true ->
        context
    end
  end

  defp step_3(context = %{halted: true}), do: context
  defp step_3(context) do
    cond do
      context.str =~ ~r{(ational|tional|alize|icate|iciti|ical|ness|ful)$} ->
        [stem,suffix, ""] = Regex.split(~r{(ational|tional|alize|icate|iciti|ical|ness|ful)$}, context.str, include_captures: true)
        if context.region1 <= String.length(stem) do
          %Context{context | str: stem <> normalize_suffix_2(suffix)}
        else
          context
        end

      context.str =~ ~r{ative$} ->
        [stem, _] = Regex.split(~r{ative$}, context.str)
        if context.region2 <= String.length(stem) do
          %Context{context | str: stem}
        else
          context
        end

      true ->
        context
    end
  end

  defp step_4(context = %{halted: true}), do: context
  defp step_4(context) do
    suffix1 = ~r{(ement|able|ance|ence|ible|ment|ant|ate|ent|ism|iti|ive|ize|ous|al|er|ic|ou)$}
    suffix2 = ~r{(s|t)ion$}

    parts = cond do
      context.str =~ suffix1 -> Regex.split(suffix1, context.str, include_captures: true)
      context.str =~ suffix2 -> Regex.split(~r{ion$}, context.str, include_captures: true)
      true -> nil
    end

    case parts do
      ["", stem, ""] -> if context.region2 <= String.length(stem), do: %Context{context | str: stem}, else: context
      [stem, _, ""] -> if context.region2 <= String.length(stem), do: %Context{context | str: stem}, else: context
      nil -> context
    end
  end

  defp step_5a(context = %{halted: true}), do: context.str
  defp step_5a(context) do
    suffix1 = ~r{e$}
    suffix2 = ~r{(.*l)l$}

    penultimate = cond do
      context.str =~ suffix1 ->
        case Regex.split(suffix1, context.str) do
          [stem, ""] -> if context.region2 <= String.length(stem) or (context.region1 <= String.length(stem) and !is_short?(stem, context.region1)), do: chop(context.str), else: context.str
          ["", stem] -> if context.region2 <= String.length(stem) or (context.region1 <= String.length(stem) and !is_short?(stem, context.region1)), do: chop(context.str), else: context.str
          nil -> context.str
        end

      context.str =~ suffix2 ->
        case Regex.run(suffix2, context.str) do
          [_,stem] ->
            if context.region2 <= String.length(stem), do: chop(context.str), else: context.str

          nil -> context.str
        end

      true ->
        context.str
    end

    String.replace(penultimate, "Y", "y")
  end

  defp chop(str) do
    String.slice(str, 0, String.length(str) - 1)
  end

  defp vowels do
    "[aeiouy]"
  end

  defp consonants do
    "[^aeiou]"
  end

  defp is_short?(word, region1) do
    region1 >= String.length(word) && ends_with_short_syllable?(word)
  end

  defp ends_with_short_syllable?(word) do
    word =~ ~r{((^#{vowels()}#{consonants()})|(#{consonants()}#{vowels()}[^aeiouywxY]))$}
  end

  defp get_regions(word) do
    region1 = case Regex.run(~r{^(gener|commun|arsen)}, word, return: :index) do
      [{_, len}|_] -> len
      nil ->
        case Regex.run(~r{#{vowels()}#{consonants()}}, word, return: :index) do
          [{pos, _}|_] -> pos + 2
          nil          -> String.length(word)
        end
    end

    {:ok, regex} = Regex.compile(".{#{region1}}#{vowels()}#{consonants()}")
    region2 = case Regex.run(regex, word, return: :index) do
      [{pos,_}|_] -> pos + region1 + 2
      nil -> String.length(word)
    end

    [region1, region2]
  end

  defp stem_exception(c) do
    case c.str do
      "skis"   -> halt(c, "ski")
      "skies"  -> halt(c, "sky")
      "dying"  -> halt(c, "die")
      "lying"  -> halt(c, "lie")
      "tying"  -> halt(c, "tie")
      "idly"   -> halt(c, "idl")
      "gently" -> halt(c, "gentl")
      "ugly"   -> halt(c, "ugli")
      "early"  -> halt(c, "earli")
      "only"   -> halt(c, "onli")
      "singly" -> halt(c, "singl")
      "sky"    -> halt(c, "sky")
      "news"   -> halt(c, "news")
      "howe"   -> halt(c, "howe")
      "atlas"  -> halt(c, "atlas")
      "cosmos" -> halt(c, "cosmos")
      "bias"   -> halt(c, "bias")
      "andes"  -> halt(c, "andes")
      _        -> c
    end
  end

  defp halt(context, word) do
    %Context{context | halted: true, str: word}
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
    stem = word |> String.replace(~r{^'}, "")
                |> String.replace(~r{^y}, "Y")
    [r1, r2] = get_regions(stem)

    %Context{region1: r1, region2: r2, str: stem, halted: false}
  end
end

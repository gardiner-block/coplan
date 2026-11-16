require "rails_helper"

RSpec.describe CoPlan::Plans::MarkdownTextExtractor do
  # Every stripped character that keeps an anchor must point at itself in the
  # source. An escaped pipe points at the pipe, not at its backslash.
  def expect_positions_to_match(content, stripped, pos_map)
    stripped.each_char.with_index do |char, index|
      next if pos_map[index].negative?

      expect(content[pos_map[index]]).to eq(char), "#{char.inspect} at #{index} mapped to #{content[pos_map[index]].inspect}"
    end
  end

  def table(row)
    "| Client | Key | Note |\n|---|---|---|\n#{row}\n"
  end

  # The cash-web i18n key format that took plan saves down with a 500.
  let(:i18n_row) { "| web | `\"<English>\\|░context░\\|<context>\"` (+ `_one`, `\\|░legal░\\|`) | end |" }

  it "maps code spans with escaped pipes and multibyte text in a table cell" do
    content = table(i18n_row)
    stripped, pos_map = described_class.call(content)

    expect(stripped).to include("\"<English>|░context░|<context>\" (+ _one, |░legal░|) end")
    expect_positions_to_match(content, stripped, pos_map)
  end

  it "maps the same cell when collecting writing source spans" do
    content = table(i18n_row)
    stripped, pos_map, spans = described_class.call(content, exclude_nonprose: true, source_spans: true)

    expect(stripped).to include("|░context░|")
    expect_positions_to_match(content, stripped, pos_map)
    expect(spans.length).to eq(stripped.length)
  end

  it "re-aligns text after escaped pipes and resets at the next cell" do
    content = table("| a\\|b\\|░ c | `x\\|y` ░z | next |")
    stripped, pos_map = described_class.call(content)

    expect(stripped).to include("a|b|░ c x|y ░z next")
    expect_positions_to_match(content, stripped, pos_map)
  end

  it "leaves an escaped backslash before a pipe alone" do
    content = table("| a\\\\|b ░ | `c\\\\|d` ░ | next |")
    stripped, pos_map = described_class.call(content)

    expect(stripped).to include("a\\|b ░ c\\\\|d ░ next")
    expect_positions_to_match(content, stripped, pos_map)
  end
end

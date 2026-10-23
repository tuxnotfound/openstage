require "rails_helper"

RSpec.describe ReadmeLine do
  it "takes the first paragraph of prose, past the heading, badges and picture" do
    readme = <<~MD
      # Uptime Kuma

      [![Build](https://img.shields.io/badge/x.svg)](https://ci.example) ![logo](logo.png)

      <p align="center"><img src="shot.png"></p>

      Uptime Kuma is an **easy-to-use** self-hosted [monitoring](https://example.com) tool.
      It watches your sites.

      ## Install
    MD

    expect(described_class.of(readme)).to eq("Uptime Kuma is an easy-to-use self-hosted monitoring tool. It watches your sites.")
  end

  it "passes over a setext heading, lists, quotes and code" do
    readme = "Wheels Off\n==========\n\n- a list\n- of things\n\n> a quote\n\n```\ncode\n```\n\nA skateboarding game in an anime look."

    expect(described_class.of(readme)).to eq("A skateboarding game in an anime look.")
  end

  it "says nothing for Rails' default README, an empty one, or one without prose" do
    rails = "# README\n\nThis README would normally document whatever steps are necessary to get the\napplication up and running."

    expect([ described_class.of(rails), described_class.of(""), described_class.of(nil), described_class.of("# Title\n\n- only\n- a list") ])
      .to eq([ nil, nil, nil, nil ])
  end

  it "keeps a long line to 200 characters, cut on a word" do
    line = described_class.of("word " * 80)

    expect(line.length).to be <= 201
    expect(line).to end_with("word…")
  end
end

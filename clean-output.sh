#!/usr/bin/env bash

DIR="$1"

# Validate arguments
if [[ -z "$DIR" ]]; then
    echo "Usage: $0 <project_directory>"
    exit 1
fi

rm -rf "$DIR"/outputDecoded/*
rm -rf "$DIR"/outputHevc/*
rm -rf "$DIR"/outputPayload/*
rm -rf "$DIR"/outputPcap/*
rm -rf "$DIR"/outputPcapLoss/*

rm -rf "$DIR"/logs/decode_loss/*
rm -rf "$DIR"/logs/encode_videos/*
rm -rf "$DIR"/logs/extract_payload/*
rm -rf "$DIR"/logs/insert_loss/*
rm -rf "$DIR"/logs/stream_videos/*

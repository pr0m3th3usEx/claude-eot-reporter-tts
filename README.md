Command to run read from stream:

```
./target/release/pocket-tts-cli generate --text "${TEST}" --voice "azelma" --stream | ffplay -f s16le -ar 24000 -ch_layout mono -nodisp -autoexit -probesize 32 -analyzeduration 0 -i pipe:0
```
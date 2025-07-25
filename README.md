![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TinyQV Full Peripheral Template for Tiny Tapeout

- [Read the documentation for project](docs/info.md)

## What is TinyQV

[TinyQV](https://github.com/TinyTapeout/ttsky25a-tinyQV) is a Risc-V CPU designed for Tiny Tapeout.

This template helps you create peripherals that can be integrated with TinyQV.

Implement your peripheral by replacing the implementation in the [example](src/peripheral.v) with your own implementation.  You may create additional modules.

Test your peripheral by replacing and extending the [example test](test/test.py).

## Submission checklist

Before submitting your design, please check:
- You have renamed the peripheral module from `tqvp_example` to something unique that makes sense for your design.
- You have created a [test script](test/test.py) that uses the `tqv` class to read and write your design's registers.
- You have [documented your design](docs/info.md) and its registers.

## Submission process

Please raise a pull request against https://github.com/TinyTapeout/ttsky25a-tinyQV adding your peripheral.  Link to your peripheral repo in the PR.

If you have any trouble following the steps below, ask in the Tiny Tapeout Discord or in the PR.

### Add your verilog source to src/user_peripherals

* If you have multiple modules create a subdirectory.
* Add each source file to the info.yaml source_files section

### Add your peripheral to the "Full interface peripherals" section in src/peripherals.v

* Each peripheral needs its own index, and you'll have to update that in 6 different places (the example shows peripheral index of 4) :
  * `.uo_out(uo_out_from_user_peri[4]),`
  * `.data_write_n(data_write_n    | {2{~peri_user[4]}}),`
  * `.data_read_n(data_read_n_peri | {2{~peri_user[4]}}),`
  * `.data_out(data_from_user_peri[4]),`
  * `.data_ready(data_ready_from_user_peri[4]),`
  * `.user_interrupt(user_interrupts[4])`

### Add your test file to test/user_peripherals

* Copy the test in to a subdirectory of test/user_peripherals
* Update your testbench.py to set the PERIPHERAL_NUM to match the value used in peripherals.v.
* In test/Makefile, add the name of your test to the all recipe. If your test is called my_peripheral.py add this: `peri-my_peripheral.xml`

To run your test, make sure you have installed the `requirements.txt`, then:

    make clean
    make peri-my_peripheral.xml

And the compressed waveform will be in `sim_build/rtl/tb.fst`

### Add your docs to docs/user_peripherals

* Copy your docs/info.md into this folder and rename it appropriately (e.g. my_peripheral.md)

## The peripheral test harness

This template includes a test harness for your peripheral that communicates with the peripheral using SPI.  This allows you to develop and test your peripheral independently of the rest of the Risc-V SoC.

The SPI interface implemented by the test harness operates in 32-bit words.  The command has the format:
| Bits | Meaning |
| ---- | ------- |
| 31    | Read or write command: 1 for a write, 0 for a read |
| 30-29 | Transaction width 0, 1 or 2 for 8, 16 or 32 bits |
| 28-6  | Unused |
| 5-0   | The register address |

For a write the next 32 bit word transmitted is the word to write to the register.  A full 32-bits word is sent even if the requested transaction width is shorter.

For a read, the test harness reads the register and transmits it back to the SPI controller.  Again, a full 32-bit word is used even if a shorter read was performed.

### Additional outputs

In the test harness, the user_interrupt is connected to `uio[0]`, to allow your test to verify interrupt generation.  Use the function `tqv.is_interrupt_asserted()` to check this, so that the same test can work once integrated with the Risc-V core.

The data_ready output is connected to `uio[1]`, and if necessary the test infrastructure will delay the SPI read until this goes high, allowing long read delays to be tested.

## Testing your design with TinyQV

When ttsky25a is delivered, the easiest way to test your design will be with [TinyQV Micropython](https://github.com/MichaelBell/micropython/tree/tinyqv-sky25a/ports/tinyQV).  The firmware will make it easy to read and write your registers, and set the output pins to be controlled by your peripheral (this is currently a work in progress).

In order to easily use TinyQV Micropython, you will need to avoid using the in7 and out0 IOs, as these are used for the UART peripheral to communicate with Micropython.  So if you don't need to use all of the IOs then avoid using those ones.

You can also integrate directly with the [tinyQV SDK](https://github.com/MichaelBell/tinyQV-sdk/tree/ttsky25a) to create programs in C.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- Edit [the docs](docs/info.md) and explain your design, how it works, and how to test it.
- Submit your preipheral for inclusion in TinyQV.  See the [Discord](https://tinytapeout.com/discord) for more details.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Bluesky [#tinytapeout](https://bsky.app/hashtag/TinyTapeout) [@TinyTapeout](https://bsky.app/profile/tinytapeout.com)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)

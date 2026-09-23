# Harmony route adaptation

Vendored from https://github.com/bggRGjQaUbCoE/getx at 3e65da893d9736135b2631a39e46c8f5388c2536 (GetX 4.7.2). LICENSE retained.

Only behavioral change: `Transition.native` selects the OHOS Flutter SDK `OpenRightwardsPageTransitionsBuilder` on OHOS, respecting reduced motion. Other platforms and route lifecycle remain unchanged. This is a Flutter platform transition, not an ArkUI Navigation stack.

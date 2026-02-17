window.BENCHMARK_DATA = {
  "lastUpdate": 1771321724849,
  "repoUrl": "https://github.com/elementary-swift/elementary-ui",
  "entries": {
    "Benchmark": [
      {
        "commit": {
          "author": {
            "email": "52261246+sliemeobn@users.noreply.github.com",
            "name": "Simon Leeb",
            "username": "sliemeobn"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "a40fcae232fa7362bfa30c1a79b28179903733c3",
          "message": "added size benchmarks and CI (#71)",
          "timestamp": "2026-02-16T17:57:54+01:00",
          "tree_id": "c4fbf76e24eda3122e9e46e4185492f09271eb7d",
          "url": "https://github.com/elementary-swift/elementary-ui/commit/a40fcae232fa7362bfa30c1a79b28179903733c3"
        },
        "date": 1771261569613,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Animations",
            "value": 157.89,
            "unit": "kB"
          },
          {
            "name": "Counter",
            "value": 130.33,
            "unit": "kB"
          },
          {
            "name": "HelloWorld",
            "value": 115.75,
            "unit": "kB"
          },
          {
            "name": "Inputs",
            "value": 160.59,
            "unit": "kB"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "name": "Simon Leeb",
            "username": "sliemeobn",
            "email": "52261246+sliemeobn@users.noreply.github.com"
          },
          "committer": {
            "name": "GitHub",
            "username": "web-flow",
            "email": "noreply@github.com"
          },
          "id": "a40fcae232fa7362bfa30c1a79b28179903733c3",
          "message": "added size benchmarks and CI (#71)",
          "timestamp": "2026-02-16T16:57:54Z",
          "url": "https://github.com/elementary-swift/elementary-ui/commit/a40fcae232fa7362bfa30c1a79b28179903733c3"
        },
        "date": 1771311342081,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Animations",
            "value": 157.9,
            "unit": "kB"
          },
          {
            "name": "Counter",
            "value": 130.33,
            "unit": "kB"
          },
          {
            "name": "HelloWorld",
            "value": 115.76,
            "unit": "kB"
          },
          {
            "name": "Inputs",
            "value": 160.6,
            "unit": "kB"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "48856104+gomminjae@users.noreply.github.com",
            "name": "Minjae Gwon",
            "username": "gomminjae"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "f9d8908ca85cb3eefdc77e540842322b851e48f8",
          "message": "Add FilterModifier with blur, saturation, brightness (#70)\n\n* Add FilterModifier with blur, saturation, brightness\n\nFollowing TransformModifier's stackable pattern:\n- CSSFilter with AnyFunction enum (blur, saturation, brightness)\n- FilterModifier with upstream chaining\n- View extensions: .blur(radius:), .saturation(_:), .brightness(_:)\n\nFilters can be combined and animated individually.\n\n* Add FilterDemoView example and animation hints to filter modifiers\n\n- Add FilterDemoView to test stacked filter animations (blur + saturation + brightness)\n- Add animation hint notes to blur, saturation, brightness modifiers\n- Include FilterDemoView in Basic example app\n\n* Fix swift-format indentation in FilterBox\n\n---------\n\nCo-authored-by: mjgwon-tech <mj.gwon@fanmaum.com>",
          "timestamp": "2026-02-17T10:45:53+01:00",
          "tree_id": "45b51981399e9123d7c761c0f2735e8a0b11c39c",
          "url": "https://github.com/elementary-swift/elementary-ui/commit/f9d8908ca85cb3eefdc77e540842322b851e48f8"
        },
        "date": 1771321723945,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "Animations",
            "value": 157.91,
            "unit": "kB"
          },
          {
            "name": "Counter",
            "value": 130.33,
            "unit": "kB"
          },
          {
            "name": "HelloWorld",
            "value": 115.77,
            "unit": "kB"
          },
          {
            "name": "Inputs",
            "value": 160.64,
            "unit": "kB"
          }
        ]
      }
    ]
  }
}
window.STORY = {
  "name": "José Alberto Buendía",
  "hint": "Scroll, or press ↓",
  "placeholder": "Placeholder",
  "opening": {
    "rail": "Opening",
    "line": "Engineer aiming at MedTech: AI applied to medicine, in biomedical data, devices and software.",
    "degree": "Industrial Technologies Engineering, Electronics. ICAI, Madrid.",
    "livedTitle": "Lived in",
    "lived": [
      {
        "place": "Basel",
        "value": "8",
        "unit": "years",
        "caption": "Switzerland"
      },
      {
        "place": "Brussels",
        "value": "3",
        "unit": "years",
        "caption": "Belgium"
      },
      {
        "place": "Madrid",
        "value": "ICAI",
        "caption": "University"
      }
    ],
    "languagesTitle": "Languages",
    "languages": [
      {
        "code": "ES",
        "name": "Spanish",
        "level": "Native"
      },
      {
        "code": "EN",
        "name": "English",
        "level": "Native"
      },
      {
        "code": "FR",
        "name": "French",
        "level": "B2"
      },
      {
        "code": "DE",
        "name": "German",
        "level": "C1"
      }
    ]
  },
  "thesis": {
    "rail": "Thesis",
    "headline": "Can synthetic heartbeats help detect atrial fibrillation?",
    "context": "Bachelor's thesis, done at IIT.",
    "strip": {
      "normal": "Normal rhythm",
      "af": "Atrial fibrillation",
      "normalNote": "Even beats, each with a P wave before the spike.",
      "afNote": "Uneven beats, no P wave, a restless baseline.",
      "disclaimer": "Illustrative trace drawn by this app. Not patient data."
    },
    "steps": [
      {
        "title": "Wavelet domain",
        "detail": "The ECG is moved into an invertible wavelet domain, so whatever is generated there converts back to a signal."
      },
      {
        "title": "WGAN-GP",
        "detail": "A WGAN-GP learns to generate synthetic ECG in that domain."
      },
      {
        "title": "EfficientNet-B0",
        "detail": "A transfer-learning classifier for atrial fibrillation, on the MIT-BIH AF Database."
      }
    ],
    "resultTitle": "Result",
    "figures": [
      {
        "value": "≈86",
        "unit": "%",
        "caption": "Accuracy on\nunseen patients"
      },
      {
        "value": "9",
        "unit": "/10",
        "caption": "Thesis\ngrade"
      }
    ],
    "finding": "The synthetic data gave no detectable gain. The classifier works; the generated heartbeats did not make it better. That is the result.",
    "repoLabel": "Open the repo",
    "repoUrl": "https://github.com/buendjo777/ecg-timescale-gan"
  },
  "desk": {
    "rail": "Desk",
    "headline": "Desk: a life desk run by nightly agents.",
    "summary": "Cloud agents read the inbox and the calendar every night and write a brief into a private git vault. Desk is the native Mac app that reads it: what is due, what needs a reply, what to confirm. It holds no credentials, renders untrusted text as plain text, and changes nothing without a click.",
    "figures": [
      {
        "value": "9",
        "caption": "Tabs"
      },
      {
        "value": "0",
        "unit": "€",
        "caption": "Running\ncost"
      },
      {
        "value": "0",
        "caption": "Third-party\npackages"
      }
    ],
    "screensNote": "Screens drawn from invented demo data.",
    "screens": [
      {
        "label": "Today",
        "file": "today"
      },
      {
        "label": "Studying",
        "file": "studying"
      },
      {
        "label": "Projects",
        "file": "projects"
      },
      {
        "label": "Tutoring",
        "file": "tutoring"
      },
      {
        "label": "System",
        "file": "system"
      }
    ],
    "architectureTitle": "Architecture",
    "architectureNote": "One writer per file · no server · no tokens in the app",
    "architecture": [
      {
        "title": "Nightly agents",
        "detail": "Read mail and calendar in the cloud"
      },
      {
        "title": "Vault (git)",
        "detail": "A brief, a run log, drafts and notes"
      },
      {
        "title": "Desk for Mac",
        "detail": "git pull · pure parsers · nine tabs"
      },
      {
        "title": "Jose",
        "detail": "Ticks, Add, Dismiss: decisions the agents read back"
      }
    ],
    "platformNote": "This portfolio runs on the same theme, glass and motion code as Desk.",
    "repoLabel": "Open the repo",
    "repoUrl": "https://github.com/buendjo777/Life_Desk_App"
  },
  "tutoring": {
    "rail": "Tutoring",
    "headline": "Four years tutoring maths, physics and chemistry.",
    "figures": [
      {
        "value": "4",
        "unit": "years",
        "caption": "Tutoring"
      },
      {
        "value": "3",
        "caption": "Subjects"
      }
    ],
    "subjects": [
      {
        "name": "Maths",
        "detail": "Includes IB Maths IAs.",
        "symbol": "function"
      },
      {
        "name": "Physics",
        "symbol": "atom"
      },
      {
        "name": "Chemistry",
        "symbol": "flask"
      }
    ],
    "factsTitle": "Who",
    "facts": [
      {
        "title": "IB students",
        "detail": "Including their Maths IAs.",
        "symbol": "graduationcap"
      },
      {
        "title": "Many nationalities",
        "detail": "An international group of students.",
        "symbol": "globe.europe.africa"
      },
      {
        "title": "Own client base",
        "detail": "Run independently.",
        "symbol": "person.2"
      }
    ]
  },
  "next": {
    "rail": "Next",
    "headline": "What comes next.",
    "goals": [
      {
        "title": "Master's",
        "value": "Autumn 2027",
        "detail": "A master's towards MedTech and AI applied to medicine."
      },
      {
        "title": "Internship",
        "value": "From December 2026",
        "detail": "Until August 2027. Switzerland and Madrid first."
      }
    ],
    "contactTitle": "Get in touch",
    "contact": [
      {
        "label": "Email",
        "value": "",
        "url": "",
        "symbol": "envelope"
      },
      {
        "label": "LinkedIn",
        "value": "",
        "url": "",
        "symbol": "person.crop.rectangle"
      },
      {
        "label": "GitHub",
        "value": "github.com/buendjo777",
        "url": "https://github.com/buendjo777",
        "symbol": "chevron.left.forwardslash.chevron.right"
      }
    ]
  }
}
;
window.THEME = {"ecg":{"baseline":0.66000000000000003,"gain":0.5,"grid":0.20000000000000001,"seconds":6},"order":["ember","oxblood","saffron"],"palettes":{"ember":{"schemes":{"dark":{"auroraCool":[77,96,144,0.41999999999999998],"auroraWarm":[255,106,61,0.070000000000000007],"canvas":[4,6,13,1],"control":[13,24,54,0.71999999999999997],"controlInk":[255,255,255,1],"deep":[13,24,54,1],"edge":[255,255,255,0.23999999999999999],"field":[[4,6,13,1],[7,13,31,1],[13,24,54,1]],"focus":[255,138,92,1],"ink":[255,255,255,1],"line":[255,255,255,0.13],"muted":[185,194,217,1],"onFocus":[4,6,13,1],"onPrimary":[4,6,13,1],"primary":[255,255,255,1],"raised":[11,20,45,0.71999999999999997],"selection":[255,138,92,0.20000000000000001],"shape":[255,255,255,0.040000000000000001],"surface":[4,6,13,0.5],"tideCore":[255,138,92,0.40000000000000002],"tideHigh":[255,106,61,0.64000000000000001],"tideLow":[255,106,61,0.34000000000000002],"tint":[255,255,255,0.083000000000000004],"tintCaution":[255,209,102,0.32000000000000001],"tintFocus":[255,138,92,0.32000000000000001]},"light":{"auroraCool":[156,184,255,0.22],"auroraWarm":[255,183,158,0.22],"canvas":[246,248,252,1],"control":[11,21,51,1],"controlInk":[255,255,255,1],"deep":[11,21,51,1],"edge":[255,255,255,0.94999999999999996],"field":[[246,248,252,1],[236,240,249,1],[255,234,223,1]],"focus":[229,83,45,1],"ink":[11,18,38,1],"line":[11,18,38,0.13],"muted":[72,81,107,1],"onFocus":[255,255,255,1],"onPrimary":[255,255,255,1],"primary":[11,18,38,1],"raised":[255,255,255,0.88],"selection":[229,83,45,0.12],"shape":[11,18,38,0.040000000000000001],"surface":[255,255,255,0.66000000000000003],"tideCore":[239,123,90,0.40000000000000002],"tideHigh":[255,183,158,0.64000000000000001],"tideLow":[255,183,158,0.34000000000000002],"tint":[11,18,38,0.083000000000000004],"tintCaution":[184,125,10,0.32000000000000001],"tintFocus":[229,83,45,0.32000000000000001]}},"title":"Midnight Ember"},"oxblood":{"schemes":{"dark":{"auroraCool":[105,96,133,0.41999999999999998],"auroraWarm":[200,50,74,0.070000000000000007],"canvas":[11,7,9,1],"control":[74,14,34,0.71999999999999997],"controlInk":[255,247,240,1],"deep":[74,14,34,1],"edge":[255,255,255,0.23999999999999999],"field":[[11,7,9,1],[30,8,17,1],[74,14,34,1]],"focus":[255,194,26,1],"ink":[255,247,240,1],"line":[255,255,255,0.13],"muted":[230,213,208,1],"onFocus":[11,7,9,1],"onPrimary":[11,7,9,1],"primary":[255,247,240,1],"raised":[56,12,27,0.71999999999999997],"selection":[255,194,26,0.20000000000000001],"shape":[255,247,240,0.040000000000000001],"surface":[11,7,9,0.5],"tideCore":[255,194,26,0.40000000000000002],"tideHigh":[200,50,74,0.64000000000000001],"tideLow":[200,50,74,0.34000000000000002],"tint":[255,255,255,0.083000000000000004],"tintCaution":[255,169,77,0.32000000000000001],"tintFocus":[255,194,26,0.32000000000000001]},"light":{"auroraCool":[142,197,255,0.22],"auroraWarm":[233,160,160,0.22],"canvas":[246,238,232,1],"control":[110,18,48,1],"controlInk":[255,247,240,1],"deep":[110,18,48,1],"edge":[255,255,255,0.94999999999999996],"field":[[246,238,232,1],[239,221,214,1],[235,199,191,1]],"focus":[158,27,63,1],"ink":[30,11,18,1],"line":[30,11,18,0.13],"muted":[90,58,68,1],"onFocus":[255,255,255,1],"onPrimary":[255,255,255,1],"primary":[30,11,18,1],"raised":[255,255,255,0.88],"selection":[158,27,63,0.12],"shape":[30,11,18,0.040000000000000001],"surface":[255,255,255,0.66000000000000003],"tideCore":[188,80,102,0.40000000000000002],"tideHigh":[233,160,160,0.64000000000000001],"tideLow":[233,160,160,0.34000000000000002],"tint":[30,11,18,0.083000000000000004],"tintCaution":[184,106,10,0.32000000000000001],"tintFocus":[158,27,63,0.32000000000000001]}},"title":"Oxblood Marigold"},"saffron":{"schemes":{"dark":{"auroraCool":[74,131,157,0.41999999999999998],"auroraWarm":[232,116,42,0.070000000000000007],"canvas":[8,10,12,1],"control":[14,77,79,0.71999999999999997],"controlInk":[242,250,247,1],"deep":[14,77,79,1],"edge":[255,255,255,0.23999999999999999],"field":[[8,10,12,1],[10,42,44,1],[14,77,79,1]],"focus":[255,158,27,1],"ink":[242,250,247,1],"line":[255,255,255,0.13],"muted":[203,223,217,1],"onFocus":[8,10,12,1],"onPrimary":[8,10,12,1],"primary":[242,250,247,1],"raised":[12,63,65,0.71999999999999997],"selection":[255,158,27,0.20000000000000001],"shape":[242,250,247,0.040000000000000001],"surface":[8,10,12,0.5],"tideCore":[255,158,27,0.40000000000000002],"tideHigh":[232,116,42,0.64000000000000001],"tideLow":[232,116,42,0.34000000000000002],"tint":[255,255,255,0.083000000000000004],"tintCaution":[255,209,102,0.32000000000000001],"tintFocus":[255,158,27,0.32000000000000001]},"light":{"auroraCool":[147,197,253,0.22],"auroraWarm":[247,197,107,0.22],"canvas":[238,243,240,1],"control":[14,77,79,1],"controlInk":[242,250,247,1],"deep":[14,77,79,1],"edge":[255,255,255,0.94999999999999996],"field":[[238,243,240,1],[217,233,227,1],[247,227,192,1]],"focus":[199,106,0,1],"ink":[10,31,32,1],"line":[10,31,32,0.13],"muted":[63,92,90,1],"onFocus":[255,255,255,1],"onPrimary":[255,255,255,1],"primary":[10,31,32,1],"raised":[255,255,255,0.88],"selection":[199,106,0,0.12],"shape":[10,31,32,0.040000000000000001],"surface":[255,255,255,0.66000000000000003],"tideCore":[218,142,43,0.40000000000000002],"tideHigh":[247,197,107,0.64000000000000001],"tideLow":[247,197,107,0.34000000000000002],"tint":[10,31,32,0.083000000000000004],"tintCaution":[168,116,8,0.32000000000000001],"tintFocus":[199,106,0,0.32000000000000001]}},"title":"Ink Saffron"}},"tideStart":0.14000000000000001}
;

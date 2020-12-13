export type LanguageName = "python" | "javascript" | "go" | "java";

export interface Language {
  install: string;
}

export type Languages = {
  [key in LanguageName]: Language;
};

export type DemoName = "basic" | "full" | "json";

export interface Demo {
  name: DemoName;
  command: string;
  video: string;
}

export type Demos = {
  [key in DemoName]: Demo;
};

export const cn = (...inputs: any[]): string => {
  return inputs.filter(Boolean).join(" ");
};

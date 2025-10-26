/**
 * Given an MDZ input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 * @param {string} input
 * @return {Promise<string>} output
 */
export function parseMDZ(input: string): Promise<string>;

/**
 * Converts the input string into a slug identifier.
 * @param {string} input
 * @return {Promise<string>} output
 */
export function slugify(input: string): Promise<string>;

// Sample application entry point

export function greet(name) {
  return `Hello, ${name}!`;
}

export function validateUser(user) {
  // BUG: Crashes on null input instead of returning false
  if (user.email && user.email.includes('@')) {
    return true;
  }
  return false;
}

export function calculateTotal(items) {
  return items.reduce((sum, item) => sum + item.price, 0);
}

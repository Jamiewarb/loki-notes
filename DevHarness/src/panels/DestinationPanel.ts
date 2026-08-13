/**
 * Destination placeholder panel — mirrors DetailHostView / DestinationPlaceholderView.
 */
export function renderDestinationPlaceholder(
  root: HTMLElement,
  opts: {
    id: string;
    title: string;
    message: string;
    iconHint: string;
  },
): void {
  root.innerHTML = `
    <div class="destination" data-harness="destination" data-destination="${opts.id}">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">${opts.iconHint}</span>
        <h2 class="destination-title">${opts.title}</h2>
      </header>
      <p class="destination-lead">${opts.message}</p>
      <div class="placeholder-surface" data-harness="placeholder">
        <p class="placeholder-kicker">App shell · PR03</p>
        <h3>${opts.title} placeholder</h3>
        <p>Sidebar navigation is live. Feature content arrives in a later PR.</p>
      </div>
    </div>
  `;
}

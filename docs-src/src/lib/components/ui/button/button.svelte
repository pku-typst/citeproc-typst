<script lang="ts">
  import type { HTMLButtonAttributes } from "svelte/elements";
  import { cn } from "$lib/utils/index.js";
  import { buttonVariants, type Variant, type Size } from "./index.js";

  type $$Props = HTMLButtonAttributes & {
    variant?: Variant;
    size?: Size;
  };

  let className: $$Props["class"] = undefined;
  export { className as class };
  export let variant: Variant = "default";
  export let size: Size = "default";
</script>

<button
  class={cn(buttonVariants({ variant, size, className }))}
  {...$$restProps}
>
  <slot />
</button>

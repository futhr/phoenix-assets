<!-- Expression-form class attribute with a reducible utility (z-[10] -> z-10)
     alongside a px spacing arbitrary (w-[180px]) that must NOT be flagged
     under a px-configured --spacing (calc(var(--spacing)*N) != literal px). -->
<div class={"z-[10] w-[180px]"}>x</div>

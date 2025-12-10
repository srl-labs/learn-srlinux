document.addEventListener("DOMContentLoaded", function () {
    // Global escape key handler for overlays
    document.addEventListener("keydown", function (e) {
        if (e.key === "Escape") {
            var overlay = document.querySelector(".code-overlay");
            if (overlay) {
                overlay.remove();

                // Reset any expand buttons back to their original state
                var expandButtons = document.querySelectorAll('[data-md-type="collapse"]');
                expandButtons.forEach(function (btn) {
                    btn.dataset.mdType = "expand";
                    if (btn.classList.contains('md-code__button')) {
                        btn.title = "Expand code";
                    } else if (btn.classList.contains('md-table__button')) {
                        btn.title = "Expand table";
                    }
                });
            }
        }
    });

    var blocks = document.querySelectorAll(".md-typeset pre");
    blocks.forEach(function (pre) {
        var code = pre.querySelector("code");
        if (!code || code.scrollWidth <= pre.clientWidth) return;
        var container = pre.parentElement;
        var copyBtn = container.querySelector(
            '.md-code__button[data-md-type="copy"]'
        );

        var btn = document.createElement("button");
        btn.className = "md-code__button md-icon";
        btn.type = "button";
        btn.dataset.mdType = "expand";
        btn.title = "Expand code";

        // if copy button is present in the code block we append the expand button after it
        if (copyBtn) {
            copyBtn.after(btn);
        } else { // if the copy button is not shown it is the case of the embed-results container; we need to add create the nav and a button
            var nav = document.createElement("nav");
            nav.className = "md-code__nav";
            nav.appendChild(btn);
            pre.appendChild(nav);
        }

        var tooltip = document.createElement("div");
        tooltip.className = "md-tooltip2 md-tooltip2--bottom";
        tooltip.setAttribute("role", "tooltip");
        var inner = document.createElement("div");
        inner.className = "md-tooltip2__inner";
        inner.textContent = btn.title;
        tooltip.appendChild(inner);
        document.body.appendChild(tooltip);

        function positionTooltip() {
            var rect = btn.getBoundingClientRect();
            tooltip.style.setProperty(
                "--md-tooltip-host-x",
                window.scrollX + rect.left + rect.width / 2 + "px"
            );
            tooltip.style.setProperty(
                "--md-tooltip-host-y",
                window.scrollY + rect.top + "px"
            );
            tooltip.style.setProperty("--md-tooltip-x", "0px");
            tooltip.style.setProperty(
                "--md-tooltip-y",
                8 + rect.height + "px"
            );
            var w = inner.offsetWidth;
            tooltip.style.setProperty("--md-tooltip-width", w + "px");
            tooltip.style.setProperty("--md-tooltip-tail", "0px");
        }

        function showTooltip() {
            positionTooltip();
            tooltip.classList.add("md-tooltip2--active");
        }

        function hideTooltip() {
            tooltip.classList.remove("md-tooltip2--active");
        }

        function closeOverlay() {
            var overlay = document.querySelector(".code-overlay");
            if (overlay) {
                overlay.remove();
                btn.dataset.mdType = "expand";
                var label = "Expand code";
                btn.title = label;
                inner.textContent = label;
            }
        }

        btn.addEventListener("mouseenter", showTooltip);
        btn.addEventListener("focus", showTooltip);
        btn.addEventListener("mouseleave", hideTooltip);
        btn.addEventListener("blur", hideTooltip);

        btn.addEventListener("click", function () {
            var overlay = document.querySelector(".code-overlay");
            if (!overlay) {
                overlay = document.createElement("div");
                overlay.className = "md-typeset code-overlay";
                var wrapper = document.createElement("div");
                wrapper.className = container.className;

                // Clone the container with all buttons
                var containerClone = container.cloneNode(true);

                // Find and update the expand button in the clone to collapse state
                var expandBtnInClone = containerClone.querySelector('.md-code__button[data-md-type="expand"]');
                if (expandBtnInClone) {
                    expandBtnInClone.dataset.mdType = "collapse";
                    expandBtnInClone.title = "Collapse code";
                }

                wrapper.appendChild(containerClone);
                overlay.appendChild(wrapper);
                document.body.appendChild(overlay);

                // Add click handler to the cloned collapse button
                expandBtnInClone.addEventListener("click", function () {
                    closeOverlay();
                });

                overlay.addEventListener("click", function (e) {
                    if (e.target === overlay) {
                        closeOverlay();
                    }
                });
            } else {
                closeOverlay();
            }
        });
    });

    var tables = document.querySelectorAll(".md-typeset table");
    tables.forEach(function (table) {
        // Create a wrapper div to position the button relative to the table
        var tableWrapper = table.parentElement;
        if (!tableWrapper.classList.contains('table-wrapper')) {
            var wrapper = document.createElement("div");
            wrapper.className = "table-wrapper";
            table.parentNode.insertBefore(wrapper, table);
            wrapper.appendChild(table);
            tableWrapper = wrapper;
        }

        var btn = document.createElement("button");
        btn.className = "md-table__button md-icon";
        btn.type = "button";
        btn.dataset.mdType = "expand";

        // Append button to the wrapper, not to a header cell
        tableWrapper.appendChild(btn);

        var tooltip = document.createElement("div");
        tooltip.className = "md-tooltip2 md-tooltip2--bottom";
        tooltip.setAttribute("role", "tooltip");
        var inner = document.createElement("div");
        inner.className = "md-tooltip2__inner";
        inner.textContent = "Expand table";
        tooltip.appendChild(inner);
        document.body.appendChild(tooltip);

        function positionTooltip() {
            var rect = btn.getBoundingClientRect();
            tooltip.style.setProperty(
                "--md-tooltip-host-x",
                window.scrollX + rect.left + rect.width / 2 + "px"
            );
            tooltip.style.setProperty(
                "--md-tooltip-host-y",
                window.scrollY + rect.top + "px"
            );
            tooltip.style.setProperty("--md-tooltip-x", "0px");
            tooltip.style.setProperty("--md-tooltip-y", 8 + rect.height + "px");
            var w = inner.offsetWidth;
            tooltip.style.setProperty("--md-tooltip-width", w + "px");
            tooltip.style.setProperty("--md-tooltip-tail", "0px");
        }

        function showTooltip() {
            positionTooltip();
            tooltip.classList.add("md-tooltip2--active");
        }

        function hideTooltip() {
            tooltip.classList.remove("md-tooltip2--active");
        }

        function closeOverlay() {
            var overlay = document.querySelector(".code-overlay");
            if (overlay) {
                overlay.remove();
                btn.dataset.mdType = "expand";
                var label = "Expand table";
                btn.title = label;
                inner.textContent = label;
            }
        }

        // Add event listeners to table header elements to show/hide button
        var thead = table.querySelector('thead');
        var headerCells = table.querySelectorAll('th');

        function showButtonHalfVisible() {
            tableWrapper.classList.add('header-hover');
        }

        function hideButton() {
            if (!btn.matches(':hover') && !btn.matches(':focus')) {
                tableWrapper.classList.remove('header-hover');
            }
        }

        // Add hover listeners to thead and th elements
        if (thead) {
            thead.addEventListener('mouseenter', showButtonHalfVisible);
            thead.addEventListener('mouseleave', hideButton);
        }

        headerCells.forEach(function (cell) {
            cell.addEventListener('mouseenter', showButtonHalfVisible);
            cell.addEventListener('mouseleave', hideButton);
        });

        btn.addEventListener("mouseenter", function () {
            showTooltip();
            showButtonHalfVisible();
        });
        btn.addEventListener("focus", function () {
            showTooltip();
            showButtonHalfVisible();
        });
        btn.addEventListener("mouseleave", function () {
            hideTooltip();
            hideButton();
        });
        btn.addEventListener("blur", function () {
            hideTooltip();
            hideButton();
        });

        btn.addEventListener("click", function () {
            var overlay = document.querySelector(".code-overlay");
            if (!overlay) {
                overlay = document.createElement("div");
                overlay.className = "md-typeset code-overlay";

                // Create a scrollable wrapper for the table
                var scrollWrapper = document.createElement("div");
                scrollWrapper.className = "table-wrapper";

                var clone = table.cloneNode(true);
                scrollWrapper.appendChild(clone);
                overlay.appendChild(scrollWrapper);
                document.body.appendChild(overlay);

                overlay.addEventListener("click", function (e) {
                    // Only close if clicking on the overlay background, not the table
                    if (e.target === overlay) {
                        closeOverlay();
                    }
                });
            } else {
                closeOverlay();
            }
        });
    });
});

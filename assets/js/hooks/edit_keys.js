export const EditKeys = {
    mounted() {
        this.parentCellEl = this.el.closest('.grid-cell');
        console.log("EditKeys hook activated on mount. Active element has id " + document.activeElement.id);
        const textEl = document.activeElement.querySelector('textarea');
        if (textEl) {
            textEl.focus();
        }
        else {
            console.error("textarea element not found")
        }
        console.log("Active element has classList " + document.activeElement.classList);
        console.log("Active element has id " + document.activeElement.id);

        // Store original value for dirty checking
        this.originalValue = textEl.value;
        this.textEl = textEl;

        // Store reference to this hook for access from GridNav
        window.currentEditKeysHook = this;

        // Add beforeunload protection
        this.beforeUnloadHandler = (e) => {
          if (this.isDirty()) {
            e.preventDefault();
            e.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
            return e.returnValue;
          }
        };
        window.addEventListener('beforeunload', this.beforeUnloadHandler);

        textEl.setSelectionRange(-1, -1);
        textEl.addEventListener('keydown', (e) => {
            // Using keydown simply because MacOs apparently doesn't emit 
            // keyup events when cmd (metaKey) is held down. 
            if (e.key === 'Tab') {
                e.preventDefault();
                var start = textEl.selectionStart;
                var end = textEl.selectionEnd;
                //console.log(textEl.value);
                var val = textEl.value;
                var selected = val.substring(start, end);
                var re = /^/gm;
                var count = selected.match(re).length;
                textEl.value = val.substring(0, start) + selected.replace(re, '\t') + val.substring(end);
                textEl.selectionStart = start;
                textEl.selectionEnd = end + count;
            }
            if ((e.metaKey || e.ctrlKey) && e.key == 'Enter') {
                //console.log("ctrl-enter detected in js hook; submit changes to line content or note");
                const chunkId = this.el.dataset.chunkId;
                const colName = this.el.dataset.colName;
                this.pushEvent('update_cell', {
                    chunk_id: chunkId,
                    col_name: colName,
                    value: textEl.value
                  });
            }
            if (e.key === 'Escape') {
                //console.log("got escape during editing")
                e.preventDefault();
                if (this.confirmDiscard()) {
                    const cell = this.el.closest('[role="gridcell"]');
                    this.pushEvent("cancel_edit");
                    cell.focus();
                }
                // If user cancels confirmation, stay in edit mode
            }
        })
      },

      // Check if the current content differs from original
      isDirty() {
        return this.textEl && this.textEl.value !== this.originalValue;
      },

      // Show confirmation dialog for discarding changes
      confirmDiscard() {
        if (!this.isDirty()) {
          return true; // No changes, safe to proceed
        }
        return window.confirm("You have unsaved changes. Are you sure you want to discard them?");
      },

      destroyed() {
        // Remove beforeunload handler
        if (this.beforeUnloadHandler) {
          window.removeEventListener('beforeunload', this.beforeUnloadHandler);
        }
        
        // Clear global reference when hook is destroyed
        if (window.currentEditKeysHook === this) {
          window.currentEditKeysHook = null;
        }
        this.parentCellEl.focus();
        this.el.removeEventListener('keydown', onkeydown);
      }
}

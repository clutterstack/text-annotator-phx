export const GridNav = {
  mounted() {
    this.currentRow = 0;
    this.currentCol = 0;
    this.selectionStart = null;

    this.getCellAt = (row, col) => {
      const rows = Array.from(this.el.querySelectorAll('[role="row"]:not(.header)'));
      return rows[row]?.querySelector(`[role="gridcell"]:nth-child(${col + 1})`);
    };

    this.isEditing = () => {
      return this.el.querySelector('textarea') !== null;
    };

    this.focusCell = () =>  {
      const targetCell = this.getCellAt(this.currentRow, this.currentCol);
      if (targetCell) {
        targetCell.focus();
      }
    }

    this.handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        if (this.selectionStart !== null) {
          // Clear selection
          this.selectionStart = null;
          this.pushEvent("clear_selection", {});
        } else {
          // Cancel editing
          this.pushEvent("cancel_edit");
        }
        return;
      }

      // Handle line number selection with Shift
      if (e.shiftKey && this.getCellAt(this.currentRow, 0)?.dataset.selectable === 'true') {
        const currentLineNums = this.getCurrentLineRange();
        if (currentLineNums) {
          if (this.selectionStart === null) {
            // Start new selection
            this.selectionStart = currentLineNums;
            this.pushEvent("start_selection", { 
              start: currentLineNums.first,
              end: currentLineNums.last
            });
          } else {
            // Update existing selection
            this.pushEvent("update_selection", {
              start: this.selectionStart.first,
              end: currentLineNums.last
            });
          }
        }
        return;
      }

      // Handle Enter for editing
      if (e.key === 'Enter' && !this.isEditing()) {
        e.preventDefault();
        this.pushEvent("start_edit", {
          row: this.currentRow,
          col: this.currentCol
        });
        return;
      }

      // Don't handle navigation when editing
      if (this.isEditing()) return;

      // Only handle arrow keys
      if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
      
      e.preventDefault();
      
      const rows = Array.from(this.el.querySelectorAll('[role="row"]:not(.header)'));
      const maxRow = rows.length - 1;
      const maxCol = this.el.querySelectorAll('[role="columnheader"]').length - 1;
      
      switch (e.key) {
        case 'ArrowUp':
          this.currentRow = Math.max(0, this.currentRow - 1);
          this.focusCell();
          break;
        case 'ArrowDown':
          this.currentRow = Math.min(maxRow, this.currentRow + 1);
          this.focusCell();
          break;
        case 'ArrowLeft':
          this.currentCol = Math.max(0, this.currentCol - 1);
          this.focusCell();
          break;
        case 'ArrowRight':
          this.currentCol = Math.min(maxCol, this.currentCol + 1);
          this.focusCell();
          break;
      }
    };

    this.getCurrentLineRange = () => {
      const cell = this.getCellAt(this.currentRow, 0);
      if (!cell) return null;

      return {
        first: parseInt(cell.dataset.firstLine),
        last: parseInt(cell.dataset.lastLine)
      };
    };
    
    this.el.addEventListener('keydown', this.handleKeyDown);
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeyDown);
  }
};
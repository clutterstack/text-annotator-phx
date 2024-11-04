export const GridNav = {
  mounted() {
    this.currentRow = 0;
    this.currentCol = 0;

    this.getCellAt = (row, col) => {
      const rows = Array.from(this.el.querySelectorAll('[role="row"]:not(.header)'));
      return rows[row]?.querySelector(`[role="gridcell"]:nth-child(${col + 1})`);
    };

    this.isEditing = () => {
      return this.el.querySelector('input[type="text"]') !== null;
    };

    this.focusCell = () =>  {
      const targetCell = this.getCellAt(this.currentRow, this.currentCol);
      if (targetCell) {
        targetCell.focus();
      }

      // Push focus event to server
      this.pushEvent("cell_focused", {
        row: this.currentRow,
        col: this.currentCol
      });
    }

    this.handleKeyDown = (e) => {
      // Don't handle navigation when editing
      // if (this.isEditing()) return;

      // Only handle arrow keys and Enter
      if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Enter', 'Escape'].includes(e.key)) return;
      
      // e.preventDefault();
      
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
        case 'Enter':
          const cell = this.getCellAt(this.currentRow, this.currentCol);
          if (cell) {
            this.pushEvent("activate_cell", {
              row: this.currentRow,
              col: this.currentCol
            });
          }
          break;
        case 'Escape':
          this.pushEvent("cancel_edit");
          break;
      }
    };
    
    this.el.addEventListener('keydown', this.handleKeyDown);
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeyDown);
  }
}
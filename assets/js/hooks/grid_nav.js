export const GridNav = {
  mounted() {
    this.currentRow = 0;
    this.currentCol = 0;

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

      // Push focus event to server -- not sure we care about this
    //   this.pushEvent("cell_focused", {
    //     row: this.currentRow,
    //     col: this.currentCol
    //   });
    // }

    this.handleKeyDown = (e) => {
      //The escape key needs to work even if editing
      if (e.key == 'Escape') {
        this.pushEvent("cancel_edit");
        return;
      }

      // if ((e.ctrlKey || e.metaKey) && e.key == 'Enter') {
      //   this.pushEvent("update_cell", {
      //     row: this.currentRow,
      //     col: this.currentCol
      //   });
      //   return;
      // }

      // Don't handle navigation when editing
      if (this.isEditing()) return;

      // Only handle arrow keys
      if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
      
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
      }
    };
    
    this.el.addEventListener('keydown', this.handleKeyDown);
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeyDown);
  }
}
export const GridNav = {

  mounted() {
    this.currentRow = 0;
    this.currentCol = 0;

    this.getCellAt = (row, col) => {
      const rows = Array.from(this.el.querySelectorAll('[role="row"]:not(.header)'));
      return rows[row]?.children[col];
    };

    this.updateVisualStates = () => {
      // Clear all visual states
      this.el.querySelectorAll('[role="gridcell"]').forEach(cell => {
        cell.setAttribute('data-focused', 'false');
        cell.setAttribute('data-selected', 'false');
      });

      // Update focus indicator
      const focusedCell = this.getCellAt(this.currentRow, this.currentCol);
      if (focusedCell) {
        focusedCell.setAttribute('data-focused', 'true');
      }

      // Update selection indicators ()
      // const cell = this.getCellAt(row, col);
      // if (cell) {
      //   cell.setAttribute('data-selected', 'true');
      // }
    };
    
    this.handleKeyDown = (e) => {
      // Only handle arrow keys
      if (!['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) return;
      
      e.preventDefault();
      
      // Get all rows (excluding header)
      const rows = Array.from(this.el.querySelectorAll('[role="row"]:not(.header)'));
      const maxRow = rows.length - 1;
      const maxCol = this.el.querySelectorAll('[role="columnheader"]').length - 1;
      
      // Calculate new position
      switch (e.key) {
        case 'ArrowUp':
          this.currentRow = Math.max(0, this.currentRow - 1);
          break;
        case 'ArrowDown':
          this.currentRow = Math.min(maxRow, this.currentRow + 1);
          break;
        case 'ArrowLeft':
          this.currentCol = Math.max(0, this.currentCol - 1);
          break;
        case 'ArrowRight':
          this.currentCol = Math.min(maxCol, this.currentCol + 1);
          break;
        case 'Enter': // Activation
          e.preventDefault();
          const cell = this.getCellAt(this.currentRow, this.currentCol);
          if (cell) {
            // Push activation event to LiveView
            this.pushEvent("cell_activated", {
              row: this.currentRow,
              col: this.currentCol,
              cellContent: cell.textContent.trim()
            });
          }
          break;
      }


      this.updateVisualStates();
      
      
      // Focus the new cell
      const targetRow = rows[this.currentRow];
      const targetCell = targetRow.children[this.currentCol];
      targetCell.focus();
      
      // Optional: Push event to server if needed
      this.pushEvent("cell_focused", {
        row: this.currentRow,
        col: this.currentCol
      });
    };
    
    // Add event listener
    document.addEventListener('keydown', this.handleKeyDown);
  },

  destroyed() {
    document.removeEventListener('keydown', this.handleKeyDown);
  }

}
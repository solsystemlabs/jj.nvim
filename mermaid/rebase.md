# Rebase Command Workflow

```mermaid
flowchart TD
    A[User Action] --> B{Action Type}
    
    B -->|Press r on commit| C[Single Commit Rebase]
    B -->|Select multiple + r| D[Multi-Commit Rebase]
    B -->|leader+a action menu| E[Action Menu]
    B -->|Command Flow Interface| F[Command Flow]
    
    %% Single Commit Rebase Flow
    C --> G[show_rebase_options_menu]
    G --> H[Rebase Options Menu]
    H --> I{Select Option}
    
    I -->|b| J[Branch Mode -b]
    I -->|s| K[Source Mode -s]
    I -->|r| L[Revisions Mode -r]
    I -->|d| M[Destination Target -d]
    I -->|a| N[Insert After -A]
    I -->|f| O[Insert Before -B]
    I -->|e| P[Toggle Skip Emptied]
    
    J --> Q[Target Selection Mode]
    K --> Q
    L --> Q
    M --> Q
    N --> Q
    O --> Q
    P --> G
    
    Q --> R[Interactive Target Selection]
    R --> S[handle_rebase_options_selection]
    S --> T[rebase_commit]
    
    %% Multi-Commit Rebase Flow
    D --> U[enter_rebase_multi_select_mode]
    U --> V[Space-bar Multi-Select]
    V --> W[show_rebase_destination_menu]
    W --> X[Target Selection]
    X --> Y[rebase_multiple_commits]
    
    %% Action Menu Flow
    E --> Z{Menu Selection}
    Z -->|Single Selection| AA[Rebase commit r]
    Z -->|Multi Selection| BB[Rebase selected commits r]
    AA --> G
    BB --> U
    
    %% Command Flow Interface
    F --> CC[Step 1: Target Selection Type]
    CC --> DD[Step 2: Interactive Target Selection]
    DD --> EE[Step 3: Flag Menu]
    EE --> FF[execute_command]
    
    %% Common Execution Path
    T --> GG[rebase function]
    Y --> GG
    FF --> GG
    
    GG --> HH[Build jj rebase command]
    HH --> II[commands.execute_with_immutable_prompt]
    II --> JJ[Execute jj command]
    JJ --> KK{Success?}
    
    KK -->|Yes| LL[Refresh log display]
    KK -->|No| MM[Show error message]
    
    %% Command Variations
    HH --> NN{Command Type}
    NN -->|Branch| OO[jj rebase -b source -d target]
    NN -->|Source| PP[jj rebase -s source -d target]
    NN -->|Revisions| QQ[jj rebase -r rev1 rev2 -d target]
    NN -->|Insert After| RR[jj rebase -s source -A target]
    NN -->|Insert Before| SS[jj rebase -s source -B target]
    
    OO --> JJ
    PP --> JJ
    QQ --> JJ
    RR --> JJ
    SS --> JJ
    
    %% Error Handling
    MM --> TT[Return to previous state]
    
    %% Validation
    T --> UU{Root Commit?}
    UU -->|Yes| VV[Show error - cannot rebase root]
    UU -->|No| GG
    VV --> TT
    
    %% Styling
    classDef userAction fill:#e1f5fe
    classDef menuAction fill:#f3e5f5
    classDef execution fill:#e8f5e8
    classDef command fill:#fff3e0
    classDef error fill:#ffebee
    
    class A,B,C,D,E,F userAction
    class G,H,I,U,V,W,X,Z,AA,BB,CC,DD,EE menuAction
    class T,Y,GG,HH,II,JJ,LL execution
    class OO,PP,QQ,RR,SS command
    class MM,VV,TT error
```

## Key Menu Options

- **b**: Branch mode (`-b`) - rebase entire branch
- **s**: Source mode (`-s`) - rebase commit and descendants  
- **r**: Revisions mode (`-r`) - rebase specific commits
- **d**: Destination target (`-d`) - standard rebase destination
- **a**: Insert after (`-A`) - insert commits after target
- **f**: Insert before (`-B`) - insert commits before target
- **e**: Toggle skip emptied commits flag

## File Locations

- **Core**: `lua/jj-nvim/jj/rebase.lua`
- **Actions**: `lua/jj-nvim/jj/actions.lua:491-501`
- **Command Flow**: `lua/jj-nvim/ui/command_flow.lua:168-204`
- **Action Menu**: `lua/jj-nvim/ui/action_menu.lua:114-118, 147-151`